import QtQuick
import Quickshell
import Quickshell.Widgets

// Small round icon button used for the power menu row in the notch header.
// Split into its own file (rather than inlined) since Quickshell's QML
// engine doesn't parse inline `component Name: Type {}` declarations.
Rectangle {
    id: root

    required property string iconName
    required property string accessibleLabel
    signal activated()

    width: 26
    height: 26
    radius: 8
    color: mouse.containsMouse ? Theme.accentSoft : "transparent"

    IconImage {
        anchors.centerIn: parent
        implicitSize: 15
        source: Quickshell.iconPath(root.iconName, root.iconName)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
