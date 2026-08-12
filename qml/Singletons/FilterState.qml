pragma Singleton

import QtQuick

/*
    Single source of truth for the finding filters.

    Every view (Live, Timeline, the Filters popup) reads and writes here, so
    filter state no longer has to be threaded through the object tree by hand.
*/
FilterCriteria {
    id: root

    // Distinct labels present in the store, for the Filters popup.
    readonly property var availableLabels: {
        let labels = []
        for (let i = 0; i < FindingStore.count; i++) {
            let item = FindingStore.get(i)
            if (item.label && labels.indexOf(item.label) === -1)
                labels.push(item.label)
        }
        labels.sort()
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
}
