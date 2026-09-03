#!/bin/bash

# Define the JavaScript payload that loops through and deletes all panels
JS_SCRIPT="const allPanels = panels(); for (var i = 0; i < allPanels.length; i++) { allPanels[i].remove(); }"

# Send the script directly to Plasma 6 via DBus using the correct camelCase service
if command -v qdbus-qt6 &> /dev/null; then
    qdbus-qt6 org.kde.PlasmaShell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS_SCRIPT"
elif command -v qdbus &> /dev/null; then
    qdbus org.kde.PlasmaShell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS_SCRIPT"
fi

