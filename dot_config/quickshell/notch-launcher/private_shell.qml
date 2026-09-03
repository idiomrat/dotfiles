import Quickshell
import Quickshell.Io

Scope {
    // External trigger point -- compositor-agnostic, so it works on KDE,
    // GNOME, Hyprland, sway, etc. Bind a global shortcut in your DE to run:
    //   qs ipc -c notch-launcher call notch toggle
    // (adjust "notch-launcher" if you named the config folder differently)
    IpcHandler {
        target: "notch"
        function toggle(): void { LauncherState.toggle() }
        function open(): void { LauncherState.open = true }
        function close(): void { LauncherState.close() }
    }

    Variants {
        model: Quickshell.screens
        Notch {}
    }
}
