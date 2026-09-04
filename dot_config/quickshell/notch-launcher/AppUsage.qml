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

    // No matter how much an app's count has decayed, keep at least this
    // many of the top-ranked apps in `counts` so the "most used" ordering
    // doesn't collapse to nothing (and fall back to pure alphabetical)
    // after a long gap between launches.
    readonly property int minKept: 6

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
        const decayed = []
        for (const id in adapter.counts)
            decayed.push([id, adapter.counts[id] * factor])

        // Rank by decayed weight so we know which ones are the "top"
        // apps to protect, regardless of the noise threshold below.
        decayed.sort((a, b) => b[1] - a[1])

        const next = {}
        decayed.forEach(([id, weight], rank) => {
            // Drop anything that's decayed down to noise so the file
            // doesn't accumulate every app you've ever launched once --
            // unless it's still one of the top `minKept` apps, in which
            // case we keep it around so the ranking has something to
            // show instead of collapsing to pure alphabetical order.
            if (weight >= 0.05 || rank < root.minKept)
                next[id] = weight
        })
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
