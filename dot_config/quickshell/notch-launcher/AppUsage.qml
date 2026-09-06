pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tracks how many times each app has been launched from the notch, so the
// list can show most-used apps first. Persisted to disk (state dir) with a
// FileView + JsonAdapter, same pattern as most Quickshell configs use for
// small bits of runtime state. Shared across monitors, like LauncherState.
QtObject {
    id: root

    // Consumers use this to invalidate derived rankings. Keeping an explicit
    // revision avoids having every caller depend on the full counts object.
    property int revision: 0

    // Returns the launch count for a DesktopEntry.id ("" / null -> 0).
    function countFor(entryId) {
        if (!entryId)
            return 0
        const c = adapter.counts[entryId]
        return c ? c : 0
    }

    // Half-life for usage counts, in days. Every elapsed half-life roughly
    // halves an app's accumulated weight, so something you used heavily a
    // few months ago but haven't touched since gradually sinks back down
    // instead of camping the top of the list forever.
    readonly property real halfLifeDays: 14

    // Decays all counts based on how long it's been since the last decay,
    // then bumps up entryId by one. Decaying lazily like this (rather than
    // on a timer) means it costs nothing while the launcher sits idle, and
    // still keeps the ranking honest every time it's actually used.
    function bump(entryId) {
        if (!entryId)
            return
        applyDecay()
        const next = Object.assign({}, adapter.counts)
        next[entryId] = (next[entryId] || 0) + 1
        adapter.counts = next
    }

    function applyDecay() {
        const now = Date.now()
        if (!adapter.lastDecay) {
            adapter.lastDecay = now
            return
        }

        const elapsedDays = (now - adapter.lastDecay) / 86400000
        // Not worth rewriting the file for sub-day gaps between launches.
        if (elapsedDays < 1)
            return

        const factor = Math.pow(0.5, elapsedDays / root.halfLifeDays)
        const next = {}
        // Every app that's ever been launched keeps a (decayed) entry
        // forever -- nothing is pruned out, so an app never fully loses
        // its recent/frequent standing and there's no cap on how many
        // apps can be tracked this way. Weights just asymptotically
        // approach zero without ever being deleted.
        for (const id in adapter.counts)
            next[id] = adapter.counts[id] * factor
        adapter.counts = next
        adapter.lastDecay = now
    }

    property FileView store: FileView {
        path: Quickshell.statePath("notch-launcher/usage.json")
        watchChanges: true
        onFileChanged: reload()
        // Covers initial disk loading, local launches, decay, and external
        // edits in one place so dependent indexes refresh exactly when data
        // changes.
        onAdapterUpdated: {
            root.revision++
            writeAdapter()
        }

        adapter: JsonAdapter {
            id: adapter
            // entry.id -> launch count (decayed over time, see applyDecay)
            property var counts: ({})
            // epoch ms of the last time decay was applied
            property var lastDecay: 0
        }
    }
}
