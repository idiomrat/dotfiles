#!/bin/bash

# Force Plasma to execute the empty layout script, wiping out all panels
if command -v qdbus-qt6 &> /dev/null; then
    qdbus-qt6 org.kde.PlasmaShell /PlasmaShell org.kde.PlasmaShell.loadLookAndFeelDefaultLayout "org.kde.plasma.desktop.clearPanels"
elif command -v qdbus &> /dev/null; then
    qdbus org.kde.PlasmaShell /PlasmaShell org.kde.PlasmaShell.loadLookAndFeelDefaultLayout "org.kde.plasma.desktop.clearPanels"
fi

