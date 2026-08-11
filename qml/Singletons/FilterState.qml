pragma Singleton

import QtQuick

/*
    Single source of truth for the finding filters.

    Every view (Live, Timeline, the Filters popup) reads and writes here, so
    filter state no longer has to be threaded through the object tree by hand.
*/
QtObject {
    id: root

    property string label: ""
    property real minConfidence: 0
    property double fromMs: 0 // epoch ms lower bound; 0 = unbounded
    property double toMs: 0   // epoch ms upper bound; 0 = unbounded

    readonly property bool active: label !== "" || minConfidence > 0
                                  || fromMs > 0 || toMs > 0

    // Distinct labels present in the store, for the Filters popup.
    readonly property var availableLabels: {
        let labels = []
        for (let i = 0; i < FindingStore.count; i++) {
            let item = FindingStore.get(i)
            if (item.label && labels.indexOf(item.label) === -1)
                labels.push(item.label)
        }
        return labels
    }

    // Number of findings currently passing the active filters.
    readonly property int matchCount: {
        // The filter properties are only read inside matches(), i.e. inside the
        // loop body. On an empty store that body never runs, so the binding
        // would capture no dependency on them and go stale. Touch them here.
        let deps = [label, minConfidence, fromMs, toMs, FindingStore.count]
        let n = 0
        for (let i = 0; i < FindingStore.count; i++) {
            let item = FindingStore.get(i)
            if (matches(item.label, item.confidence, item.timestamp))
                n++
        }
        return n
    }

    function matches(itemLabel, confidence, timestamp) {
        // Exact match: the filter comes from a radio button listing existing
        // labels, so "car" must not also select "caravan".
        if (root.label !== "" && itemLabel !== root.label)
            return false
        if (confidence < root.minConfidence)
            return false
        if (root.fromMs > 0 && timestamp < root.fromMs)
            return false
        if (root.toMs > 0 && timestamp > root.toMs)
            return false
        return true
    }

    function apply(label, minConfidence, fromMs, toMs) {
        root.label = label
        root.minConfidence = minConfidence
        root.fromMs = fromMs
        root.toMs = toMs
    }

    function clear() {
        root.apply("", 0, 0, 0)
    }

    function rangeSummary() {
        let f = root.fromMs > 0
            ? Qt.formatDateTime(new Date(root.fromMs), "dd MMM HH:mm") : ""
        let t = root.toMs > 0
            ? Qt.formatDateTime(new Date(root.toMs), "dd MMM HH:mm") : ""
        if (f && t)
            return f + " → " + t
        if (f)
            return qsTr("from ") + f
        return qsTr("until ") + t
    }

    function summary() {
        let parts = []
        if (root.label !== "")
            parts.push(root.label)
        if (root.minConfidence > 0)
            parts.push("≥" + Math.round(root.minConfidence * 100) + "%")
        if (root.fromMs > 0 || root.toMs > 0)
            parts.push(root.rangeSummary())
        return parts.join("  ·  ")
    }
}
