// Gap Tiler for KWin (Plasma 6 scripting API)
// New windows are positioned GAP pixels away from the screen's client-area edges.
// After the initial placement, the script does nothing else to the window.

var GAP = 28;

var EXCLUDED_CLASSES = [
    'Godot_Engine Personal Companion (for PC!)'
];

function isExcluded(window) {
    var resourceClass = window.resourceClass ? String(window.resourceClass).toLowerCase() : '';
    var resourceName = window.resourceName ? String(window.resourceName).toLowerCase() : '';
    var caption = window.caption ? String(window.caption).toLowerCase() : '';

    // KDE's "Special Window Settings" dialog can show resourceClass and
    // resourceName together as one window-class string, while KWin exposes
    // them as separate properties. Check both possible combinations.
    var combinedA = (resourceClass + ' ' + resourceName).trim();
    var combinedB = (resourceName + ' ' + resourceClass).trim();

    for (var i = 0; i < EXCLUDED_CLASSES.length; i++) {
        var excluded = EXCLUDED_CLASSES[i].toLowerCase();

        if (resourceClass.indexOf(excluded) !== -1 ||
            resourceName.indexOf(excluded) !== -1 ||
            caption.indexOf(excluded) !== -1 ||
            combinedA.indexOf(excluded) !== -1 ||
            combinedB.indexOf(excluded) !== -1 ||
            (excluded.indexOf(resourceClass) !== -1 && resourceClass.length > 2) ||
            (excluded.indexOf(resourceName) !== -1 && resourceName.length > 2)) {
            return true;
            }
    }

    return false;
}

function isEligible(window) {
    if (!window) return false;
    if (window.deleted) return false;
    if (!window.normalWindow) return false;
    if (window.specialWindow) return false;
    if (window.fullScreen) return false;
    if (isExcluded(window)) return false;

    return true;
}

function fitToScreenWithGap(window) {
    if (!isEligible(window)) return;
    if (window.move || window.resize) return;

    var area = workspace.clientArea(KWin.MaximizeArea, window);

    var newGeom = {
        x: area.x + GAP,
        y: area.y + GAP,
        width: area.width - GAP * 2,
        height: area.height - GAP * 2
    };

    if (newGeom.width <= 0 || newGeom.height <= 0) return;

    window.frameGeometry = newGeom;
}

function applyGap(window) {
    fitToScreenWithGap(window);
}

workspace.windowAdded.connect(applyGap);
