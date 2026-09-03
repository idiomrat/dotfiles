pragma Singleton
import QtQuick
import Quickshell

// Builds one shared, searchable index of desktop entries.  Notch.qml is
// instantiated once per screen, so keeping this here prevents each monitor
// from copying and sorting the complete application list.
QtObject {
    id: root

    property bool loaded: false
    property var entries: []
    property int rankedForRevision: -1
    property var rankedEntries: []

    function ensureLoaded() {
        if (loaded)
            return

        const indexed = []
        const applications = DesktopEntries.applications.values
        for (let i = 0; i < applications.length; ++i) {
            const entry = applications[i]
            if (!entry || !entry.name)
                continue
            indexed.push({
                entry: entry,
                // Normalise once, rather than for every entry on every keypress.
                searchName: entry.name.toLocaleLowerCase(),
                sortName: entry.name
            })
        }

        // This is the stable order for apps with equal usage.
        indexed.sort((a, b) => a.sortName.localeCompare(b.sortName))
        entries = indexed
        loaded = true
    }

    function ranking() {
        ensureLoaded()
        if (rankedForRevision === AppUsage.revision)
            return rankedEntries

        const next = entries.slice()
        next.sort((a, b) => {
            const usage = AppUsage.countFor(b.entry.id) - AppUsage.countFor(a.entry.id)
            return usage !== 0 ? usage : a.sortName.localeCompare(b.sortName)
        })
        rankedEntries = next
        rankedForRevision = AppUsage.revision
        return rankedEntries
    }

    // Results are already in the correct usage/alphabetical order, so a
    // search only filters a small shared array instead of sorting again.
    function search(query) {
        const needle = query.trim().toLocaleLowerCase()
        const source = ranking()
        if (needle === "")
            return source.map(item => item.entry)

        const matches = []
        for (let i = 0; i < source.length; ++i) {
            const item = source[i]
            if (item.searchName.includes(needle))
                matches.push(item.entry)
        }
        return matches
    }
}
