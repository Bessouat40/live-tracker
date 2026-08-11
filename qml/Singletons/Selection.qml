pragma Singleton

import QtQuick

/*
    The currently highlighted finding, shared by the Live list, the map and the
    timeline fresco so a click in one view is reflected in the others.
*/
QtObject {
    id: root

    // Index into FindingStore, or -1 for "nothing selected".
    property int index: -1

    function clear() {
        root.index = -1
    }
}
