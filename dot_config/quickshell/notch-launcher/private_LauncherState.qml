pragma Singleton
import QtQuick

// Shared open/closed state driven by the external toggle (F8 via IPC).
// Each Notch instance also has its own local hover-driven state; this
// singleton just adds a global "force open" on top of that.
QtObject {
    property bool open: false

    function toggle() { open = !open }
    function close() { open = false }
}
