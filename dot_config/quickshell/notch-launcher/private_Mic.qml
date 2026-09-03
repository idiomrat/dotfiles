pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Live mic-mute status via PipeWire. This ships as part of Quickshell
// itself (the Quickshell.Services.Pipewire module), so it doesn't pull in
// anything beyond the PipeWire stack that's already driving audio on
// virtually every modern distro -- KDE/Plasma included. Notch.qml watches
// `muted` (via MicIndicator.qml) to show and pulse the mic icon.
QtObject {
    id: root

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool available: source !== null
    readonly property bool muted: available && !!source.audio && source.audio.muted

    // A PwNode's live properties (volume, muted, ...) only stay up to date
    // while something is tracking it -- an untracked node's `audio` block
    // is stale. This re-points itself automatically whenever the default
    // source changes (e.g. you plug in a headset mic).
    property PwObjectTracker tracker: PwObjectTracker {
        objects: root.source ? [root.source] : []
    }
}
