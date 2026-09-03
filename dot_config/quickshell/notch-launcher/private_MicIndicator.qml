import QtQuick
import Quickshell
import Quickshell.Widgets

// Small mic-status icon used in both the collapsed pill and the expanded
// header. Reflects Mic.muted live and does a quick pulse whenever it flips,
// so a mute toggle is noticeable even out of the corner of your eye. Split
// into its own file since it's used twice and Quickshell's QML engine
// doesn't parse inline `component Name: Type {}` declarations (see
// PowerButton.qml).
Item {
    id: root

    // Nothing to show if there's no default source at all (e.g. no mic
    // connected) -- collapses to zero width so it doesn't leave a gap in
    // whatever Row it's placed in.
    visible: Mic.available
    implicitWidth: visible ? 16 : 0
    implicitHeight: 16

    IconImage {
        id: icon
        anchors.centerIn: parent
        implicitSize: 13
        source: Mic.muted
            ? Quickshell.iconPath("microphone-sensitivity-muted-symbolic", "audio-input-microphone-muted")
            : Quickshell.iconPath("microphone-sensitivity-high-symbolic", "audio-input-microphone")
    }

    // Explicit on-demand animation (rather than a Behavior on scale) so it
    // plays the same short bounce every time, regardless of how `muted`
    // changed.
    SequentialAnimation {
        id: pulse
        NumberAnimation { target: icon; property: "scale"; to: 1.35; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: icon; property: "scale"; to: 1.0; duration: 140; easing.type: Easing.InOutQuad }
    }

    Connections {
        target: Mic
        function onMutedChanged() { pulse.restart() }
    }
}
