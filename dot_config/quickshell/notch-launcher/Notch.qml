pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

// One instance of this is created per screen (see shell.qml).
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // ---- state ----
    property bool localOpen: false

    // Identify if this notch instance is on the primary/first monitor
    readonly property bool isMainMonitor: modelData === Quickshell.screens[0]

    // Expand if hovered locally, OR if it's the main monitor AND F8 was pressed
    readonly property bool expanded: localOpen || (isMainMonitor && LauncherState.open)

    property string query: ""
    property int selectedIndex: 0 // Tracks arrow key selection

    property string pendingPowerAction: ""
    property bool suppressReopen: false

    Timer {
        id: suppressReopenTimer
        interval: Theme.animMs + 50
        onTriggered: root.suppressReopen = false
    }

    property bool workspaceFlash: false

    Timer {
        id: workspaceFlashTimer
        interval: 1400
        onTriggered: root.workspaceFlash = false
    }

    Connections {
        target: Workspaces
        function onSwitched() {
            root.workspaceFlash = true
            workspaceFlashTimer.restart()
        }
    }

    readonly property int topGap: 0

    anchors {
        top: true
        left: true
        right: true
    }
    color: "transparent"
    // Deliberately NOT bound to notch.height. If this tracked the animated
    // height, every frame of the expand/collapse animation would resize the
    // actual wl_surface (a real compositor configure/ack_configure round
    // trip) instead of just repainting -- much heavier than a plain
    // repaint, and the likely cause of the animation looking laggier on
    // secondary monitors (extra cost stacking on top of cross-GPU copies
    // for a dGPU/eGPU-driven external display, or a secondary output on a
    // different refresh rate). Pinning this to the expanded size keeps the
    // surface itself a constant size; the mask below still restricts the
    // actual visible/interactive area to the (animated) collapsed or
    // expanded shape, so nothing about click-through or hover changes.
    implicitHeight: notch.expandedH + topGap

    exclusiveZone: notch.collapsedVisibleH
    focusable: expanded
    mask: Region { item: maskShape }

    // Keep the collapsed clock pill *below* fullscreen surfaces (its normal
    // resting state), but let the launcher itself rise *above* fullscreen
    // content while open -- otherwise a keyboard-focused search box would be
    // unreachable behind a fullscreen video/game. Tying this to `expanded`
    // (rather than leaving it fixed) also makes sure the surface drops back
    // below fullscreen the instant it collapses again, instead of staying
    // stuck "on top" from having briefly held keyboard focus.
    //
    // `startupNudge` ORs into this on boot only -- see below. Toggling the
    // wlr-layer-shell layer is a real protocol-level renegotiation (not just
    // a QML property), which forces the compositor to send a fresh
    // `configure` for this surface. On some monitors, especially a 2nd
    // display whose output geometry/exclusive-zone stacking hasn't fully
    // settled yet by the time this surface is first created at boot, the
    // very first configure can land with stale info and the surface ends up
    // sitting lower than the real top edge -- fixed once *anything* forces a
    // renegotiation, which previously only happened the first time you
    // opened the notch. This does the same nudge automatically, shortly
    // after startup, without changing `expanded` so there's no visible
    // flash of the launcher opening.
    WlrLayershell.layer: (root.expanded || root.startupNudge) ? WlrLayer.Overlay : WlrLayer.Top

    // See note above: this monitor's very first layer-shell configure is
    // reliably wrong (confirmed reproducible on every Quickshell restart,
    // and independent of which display is set as primary -- it's specific
    // to this output, not a boot-timing race). A single quick renegotiation
    // shortly after creation is enough; no need to guess or retry.
    property bool startupNudge: false

    Timer {
        interval: 250
        running: true
        onTriggered: {
            root.startupNudge = true
            startupNudgeOffTimer.start()
        }
    }
    Timer {
        id: startupNudgeOffTimer
        interval: 50
        onTriggered: {
            root.startupNudge = false
            root.readyToShow = true
        }
    }

    // Stays false until the startup nudge above has run once, so the pill
    // never gets shown at the (possibly wrong) pre-nudge position -- see
    // the fade-in Behavior on the `notch` Rectangle's opacity.
    property bool readyToShow: false

    function closeLauncher() {
        root.localOpen = false
        root.suppressReopen = true
        suppressReopenTimer.restart()
        LauncherState.close()
        root.query = ""
        searchField.text = ""
        root.selectedIndex = 0
        root.pendingPowerAction = ""
        searchField.focus = false
    }

    function launch(entry) {
        // Bumping AppUsage changes the sort key that `filteredApps` is
        // ordered by, which can reorder/recycle the very ListView delegate
        // whose MouseArea is invoking this function. Doing that bump here
        // (synchronously, while this call is still on that delegate's own
        // event-handler stack) is a use-after-free waiting to happen --
        // deferring it with Qt.callLater lets the click handler finish and
        // unwind before the model is touched.
        entry.execute()
        closeLauncher()
        Qt.callLater(() => AppUsage.bump(entry.id))
    }

    function handleEscape() {
        if (root.pendingPowerAction !== "") {
            root.cancelPower()
        } else {
            root.closeLauncher()
        }
    }

    function requestPower(action) {
        root.pendingPowerAction = action
        searchField.focus = false
        notch.forceActiveFocus()
    }

    function cancelPower() {
        root.pendingPowerAction = ""
        Qt.callLater(() => searchField.forceActiveFocus())
    }

    readonly property var powerCommands: ({
        lock: ["loginctl", "lock-session"],
        logout: ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""],
        restart: ["systemctl", "reboot"],
        shutdown: ["systemctl", "poweroff"]
    })

    function powerActionLabel(action) {
        switch (action) {
            case "lock": return "Lock the screen?"
            case "logout": return "Log out?"
            case "restart": return "Restart the system?"
            case "shutdown": return "Shut down the system?"
            default: return ""
        }
    }

    function confirmPower() {
        const cmd = root.powerCommands[root.pendingPowerAction]
        if (cmd) {
            Quickshell.execDetached(cmd)
            root.closeLauncher()
        }
    }

    onExpandedChanged: {
        if (expanded) {
            Qt.callLater(() => searchField.forceActiveFocus())
        } else {
            root.selectedIndex = 0
            appList.positionViewAtBeginning()
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ScriptModel {
        id: filteredApps
        values: {
            const q = root.query.trim().toLowerCase()
            let apps = [...DesktopEntries.applications.values].filter(e => e.name)
            if (q !== "")
                apps = apps.filter(e => e.name.toLowerCase().includes(q))

                return apps.sort((a, b) => {
                    const usage = AppUsage.countFor(b.id) - AppUsage.countFor(a.id)
                    return usage !== 0 ? usage : a.name.localeCompare(b.name)
                })
        }
    }

    Item {
        id: maskShape
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: -8
        }
        width: root.readyToShow ? (root.expanded ? notch.expandedW : notch.collapsedW) : 0
        height: root.readyToShow ? (root.expanded ? notch.expandedH : notch.collapsedH) : 0
    }

    // ---------------- the notch itself ----------------
    Rectangle {
        id: notch
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: -8
        }

        property real openT: root.expanded ? 1 : 0
        Behavior on openT {
            NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutCubic }
        }

        readonly property real contentT: root.expanded ? 1 : 0

        readonly property real collapsedW: collapsedRow.implicitWidth + 10
        readonly property real expandedW: Theme.expandedWidth
        readonly property real collapsedH: Theme.collapsedHeight - 6 + 8
        readonly property real expandedH: Theme.expandedHeight + 8

        readonly property real collapsedVisibleH: Theme.collapsedHeight - 6

        width: collapsedW + (expandedW - collapsedW) * openT
        height: collapsedH + (expandedH - collapsedH) * openT

        radius: 5
        color: Theme.bg
        border.width: 0

        opacity: root.readyToShow ? 1 : 0
        clip: true

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                if (!root.suppressReopen)
                    root.localOpen = true
            }
            onExited: root.suppressReopen = false
        }

        Keys.onEscapePressed: root.handleEscape()
        focus: root.expanded

        // ---------- collapsed: date + time ----------
        Row {
            id: collapsedRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 4
            spacing: 6

            opacity: (1 - notch.openT) * (root.workspaceFlash ? 0 : 1)

            MicIndicator {
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Qt.formatDateTime(clock.date, "ddd d MMM")
                color: Theme.fg
                font.pixelSize: 12
            }
            Text {
                text: Qt.formatDateTime(clock.date, "h:mm AP")
                color: Theme.fg
                font.pixelSize: 13
                font.bold: false
            }
        }

        // ---------- collapsed: workspace-switch flash ----------
        Row {
            id: workspaceRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 4
            spacing: 7

            opacity: (1 - notch.openT) * (root.workspaceFlash ? 1 : 0)
            visible: opacity > 0

            Repeater {
                model: Workspaces.count
                delegate: Rectangle {
                    required property int index
                    width: (index + 1) === Workspaces.current ? 9 : 7
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: (index + 1) === Workspaces.current ? Theme.accent : Theme.border
                }
            }
        }

        // ---------- expanded: launcher ----------
        Column {
            anchors {
                fill: parent
                leftMargin: 16
                rightMargin: 16
                bottomMargin: 16
                topMargin: 24
            }
            spacing: 12
            opacity: notch.contentT
            visible: opacity > 0

            Item {
                width: parent.width
                height: 26

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Text {
                        text: Qt.formatDateTime(clock.date, "h:mm AP")
                        color: Theme.fg
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Text {
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        color: Theme.fgMuted
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MicIndicator {
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    PowerButton {
                        iconName: "system-lock-screen"
                        accessibleLabel: "Lock"
                        onActivated: root.requestPower("lock")
                    }
                    PowerButton {
                        iconName: "system-log-out"
                        accessibleLabel: "Log out"
                        onActivated: root.requestPower("logout")
                    }
                    PowerButton {
                        iconName: "system-reboot"
                        accessibleLabel: "Restart"
                        onActivated: root.requestPower("restart")
                    }
                    PowerButton {
                        iconName: "system-shutdown"
                        accessibleLabel: "Shut down"
                        onActivated: root.requestPower("shutdown")
                    }
                }
            }

            Rectangle {
                visible: root.pendingPowerAction === ""
                width: parent.width
                height: 40
                radius: 10
                color: Theme.accentSoft
                border.width: searchField.activeFocus ? 1 : 0
                border.color: Theme.accent

                TextInput {
                    id: searchField
                    anchors.fill: parent
                    anchors.margins: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font.pixelSize: 14
                    clip: true

                    onTextChanged: {
                        root.query = text
                        root.selectedIndex = 0
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            if (root.selectedIndex < filteredApps.values.length - 1) {
                                root.selectedIndex++
                                appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (root.selectedIndex > 0) {
                                root.selectedIndex--
                                appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            }
                            event.accepted = true
                        }
                    }

                    Keys.onEscapePressed: root.handleEscape()

                    Keys.onReturnPressed: {
                        if (filteredApps.values.length > 0 && root.selectedIndex < filteredApps.values.length)
                            root.launch(filteredApps.values[root.selectedIndex])
                    }
                }

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: "Search apps…"
                    color: Theme.fgMuted
                    font.pixelSize: 14
                    visible: searchField.text.length === 0
                }
            }

            ListView {
                id: appList
                width: parent.width
                height: parent.height - 90
                visible: root.pendingPowerAction === ""
                clip: true
                spacing: 2
                model: filteredApps

                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 46
                    radius: 8

                    color: (index === root.selectedIndex || appMouse.containsMouse) ? Theme.accentSoft : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 10

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 28
                            source: Quickshell.iconPath(appRow.modelData.icon, "application-x-executable")
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: appRow.modelData.name
                                color: Theme.fg
                                font.pixelSize: 13
                            }
                            Text {
                                text: appRow.modelData.comment || ""
                                color: Theme.fgMuted
                                font.pixelSize: 11
                                visible: text.length > 0
                            }
                        }
                    }

                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launch(appRow.modelData)
                        onEntered: root.selectedIndex = index
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 90 + 40 + 12
                visible: root.pendingPowerAction !== ""

                Column {
                    anchors.centerIn: parent
                    spacing: 18

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.powerActionLabel(root.pendingPowerAction)
                            color: Theme.fg
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "This can't be undone."
                            color: Theme.fgMuted
                            font.pixelSize: 12
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Rectangle {
                            width: 108
                            height: 38
                            radius: 10
                            color: cancelMouse.containsMouse ? Theme.bgHover : Theme.bg
                            border.width: 1
                            border.color: Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: Theme.fg
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: cancelMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cancelPower()
                            }
                        }

                        Rectangle {
                            width: 108
                            height: 38
                            radius: 10
                            color: confirmMouse.containsMouse ? Theme.accentText : Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: "Confirm"
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: confirmMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirmPower()
                            }
                        }
                    }
                }
            }
        }
    }
}
