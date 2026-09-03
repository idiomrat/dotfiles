/*
 * Follow Window Workspace
 *
 * When a window is moved to another monitor, follow it to the virtual desktop
 * that KWin's window rules assign to it.
 *
 * Handles:
 *   - Interactive drag / Alt+F7-style moves
 *   - KWin's "Move Window to Next/Previous/Left/Right Screen" hotkeys
 *   - Other moves that change a window's output
 *
 * Designed for KWin 6 / Plasma 6.
 *
 * Tracks windows only while they exist and cleans up all references when
 * a window closes.
 */

let movingWindow = null;
let startOutput = null;

const windows = new Set();
const outputChanges = new Map();

function switchToWindowDesktop(window) {
    if (!window || !window.output) {
        return;
    }

    // A window on all desktops has no single desktop to follow.
    if (window.onAllDesktops || !window.desktops || window.desktops.length !== 1) {
        return;
    }

    const desktop = window.desktops[0];
    if (!desktop) {
        return;
    }

    workspace.setCurrentDesktopForScreen(desktop, window.output);
}

function beginMove(window) {
    if (!window || !window.normalWindow || !window.moveableAcrossScreens) {
        return;
    }

    movingWindow = window;
    startOutput = window.output;
}

function finishMove(window) {
    if (window !== movingWindow) {
        return;
    }

    const oldOutput = startOutput;

    movingWindow = null;
    startOutput = null;

    if (!oldOutput || !window.output || window.output === oldOutput) {
        return;
    }

    // At this point the interactive move is finished. KWin may already have
    // applied the window rule, so follow the desktop it currently has.
    switchToWindowDesktop(window);

    // Keep tracking this output so a later desktopsChanged() caused by a rule
    // can still make the destination screen follow the final desktop.
    outputChanges.set(window, window.output);
}

function outputChanged(window) {
    if (!window || !window.output || window === movingWindow) {
        return;
    }

    const previousOutput = outputChanges.get(window);

    // First observation of a window: just establish its current monitor.
    if (!previousOutput) {
        outputChanges.set(window, window.output);
        return;
    }

    if (previousOutput === window.output) {
        return;
    }

    outputChanges.set(window, window.output);

    // The built-in move-to-screen actions arrive here. The rule may assign the
    // desktop before or after this signal, so desktopsChanged() also calls the
    // same function while the output remains marked as the new destination.
    switchToWindowDesktop(window);
}

function desktopAssignmentChanged(window) {
    if (!window || window === movingWindow) {
        return;
    }

    // Only react to desktop changes after the window has changed monitors.
    if (!outputChanges.has(window)) {
        return;
    }

    switchToWindowDesktop(window);
}

function untrackWindow(window) {
    windows.delete(window);
    outputChanges.delete(window);

    if (movingWindow === window) {
        movingWindow = null;
        startOutput = null;
    }
}

function trackWindow(window) {
    if (!window || windows.has(window)) {
        return;
    }

    windows.add(window);
    outputChanges.set(window, window.output);

    window.interactiveMoveResizeStarted.connect(function () {
        beginMove(window);
    });

    window.interactiveMoveResizeFinished.connect(function () {
        finishMove(window);
    });

    // Covers KWin's move-window-to-screen hotkeys and other non-interactive
    // moves. outputChanged() has no signal arguments in KWin 6, so we compare
    // against the output stored above.
    window.outputChanged.connect(function () {
        outputChanged(window);
    });

    // Window rules can change a window's desktop after its output changes.
    window.desktopsChanged.connect(function () {
        desktopAssignmentChanged(window);
    });

    // Remove all references when the window is destroyed.
    window.closed.connect(function () {
        untrackWindow(window);
    });
}

workspace.windowAdded.connect(trackWindow);

// Windows that already exist when the script is loaded.
const existingWindows = workspace.stackingOrder;

for (let i = 0; i < existingWindows.length; ++i) {
    trackWindow(existingWindows[i]);
}
