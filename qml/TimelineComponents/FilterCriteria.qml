import QtQuick

QtObject {
    id: root

    property string label: ""
    property real minConfidence: 0
    property double fromMs: 0
    property double toMs: 0

    readonly property bool active: label !== "" || minConfidence > 0
                                   || fromMs > 0 || toMs > 0

    function matches(itemLabel, confidence, timestamp) {
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

    function select(list, timeKey) {
        let deps = [label, minConfidence, fromMs, toMs]
        let key = timeKey || "timestamp"
        let out = []
        for (let i = 0; i < list.length; i++) {
            let e = list[i]
            if (matches(e.label, e.confidence, e[key]))
                out.push(e)
        }
        return out
    }

    function labelsIn(list) {
        let out = []
        for (let i = 0; i < list.length; i++) {
            let l = list[i].label
            if (l && out.indexOf(l) === -1)
                out.push(l)
        }
        out.sort()
        return out
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
