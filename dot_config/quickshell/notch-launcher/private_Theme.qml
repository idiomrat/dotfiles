pragma Singleton
import QtQuick

// Shared design tokens for the notch + launcher.
// Edit colors/sizes here and everything else updates.
QtObject {
    // ---- palette: white / black / #aaaaff ----
    readonly property color bg: "#ffffff"          // notch + launcher background
    readonly property color bgHover: "#f4f4fb"      // subtle hover wash
    readonly property color fg: "#111111"           // primary text (near-black)
    readonly property color fgMuted: "#7a7a7a"      // secondary text
    readonly property color border: "#e7e7ee"       // hairline borders
    readonly property color accent: "#aaaaff"       // the accent color
    readonly property color accentSoft: "#eeeeff"   // accent tint for hover/focus states
    readonly property color accentText: "#5a5ad6"   // darker accent for readable text-on-white

    // ---- sizing ----
    readonly property int collapsedWidth: 230
    readonly property int collapsedHeight: 34
    readonly property int expandedWidth: 560
    readonly property int expandedHeight: 440
    readonly property int cornerRadius: 16

    // ---- animation ----
    readonly property int animMs: 125
    readonly property int collapseContentMs: 0
}
