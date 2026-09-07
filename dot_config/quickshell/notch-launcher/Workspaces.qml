pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live KDE virtual-desktop (workspace) state, read straight off KWin's own
// D-Bus interface (org.kde.KWin /VirtualDesktopManager) -- no extra
// packages needed beyond what any Plasma session already ships: `qdbus`
// (or Plasma 6's renamed `qdbus6`/`qdbus-qt6`) and `dbus-monitor`, both part of the
// standard dbus/Qt tooling. On a non-KDE session the helper script below
// just fails quietly and `current`/`count` sit at their defaults, so the
// notch simply never shows a workspace flash.
//
// You can sanity-check the underlying calls yourself first:
//   qdbus org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.current
//   qdbus org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.count
// (swap in `qdbus6` or `qdbus-qt6` if `qdbus` isn't found).
// If your Plasma version's interface differs, tweak `script` below to match.
QtObject {
    id: root

    property int current: 1
    property int count: 1

    // Fires on every desktop switch -- but NOT for the very first reading
    // we get on startup, so opening the shell doesn't itself trigger a
    // workspace flash on every monitor.
    signal switched()
    property bool seenFirst: false

    // Prints "current/count" once immediately, then again every time KWin
    // emits currentChanged -- pushed via dbus-monitor rather than polled,
    // so this costs nothing while you're not switching desktops.
    readonly property string script: `
    QDBUS=$(command -v qdbus-qt6 || command -v qdbus6 || command -v qdbus)
    [ -z "$QDBUS" ] && exit 1

    get_state() {
        cur=$("$QDBUS" org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.current 2>/dev/null)
        cnt=$("$QDBUS" org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.count 2>/dev/null)
        rows=$("$QDBUS" --literal org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.desktops 2>/dev/null)

        [ -z "$cnt" ] || [ -z "$cur" ] && return

        # Parse the single-line struct array with awk, extracting the
        # 0-based index right before our active UUID. $cur is passed in via
        # -v as a plain data value (never spliced into the awk program
        # text), and matched with index()/substr() -- a literal substring
        # search, not a regex -- so nothing in $cur (quotes, backslashes,
        # regex metacharacters, whatever KWin hands us) can be interpreted
        # as program syntax. The only actual regex used (\\(uss\\) [0-9]+, $)
        # is a fixed pattern that never incorporates $cur.
        raw_idx=$(echo "$rows" | awk -v cur="$cur" '
        {
            pos = index($0, "\\"" cur "\\"")
            if (pos > 0) {
                prefix = substr($0, 1, pos - 1)
                if (match(prefix, /\\(uss\\) [0-9]+, $/)) {
                    numpart = substr(prefix, RSTART, RLENGTH)
                    gsub(/[^0-9]/, "", numpart)
                    print numpart
                    exit
                }
            }
        }')

        if [ -n "$raw_idx" ]; then
            idx=$((raw_idx + 1))
            else
                idx=1
                fi

                echo "$idx/$cnt"
    }

    get_state
    dbus-monitor --session "type='signal',interface='org.kde.KWin.VirtualDesktopManager',member='currentChanged'" 2>/dev/null | grep --line-buffered '^signal ' | while read -r _; do get_state; done
    `

    property Process proc: Process {
        command: ["sh", "-c", root.script]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const m = /^(\d+)\/(\d+)\s*$/.exec(line.trim())
                if (!m)
                    return

                    const nextCount = parseInt(m[2], 10)
                    const nextCurrent = parseInt(m[1], 10)

                    root.count = nextCount

                    // Consume the initial reading on startup without flashing
                    if (!root.seenFirst) {
                        root.current = nextCurrent
                        root.seenFirst = true
                        return
                    }

                    // Trigger switched() on every subsequent desktop change
                    if (root.current !== nextCurrent) {
                        root.current = nextCurrent
                        root.switched()
                    }
            }
        }
    }
}
