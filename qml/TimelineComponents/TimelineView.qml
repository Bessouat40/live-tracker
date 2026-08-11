pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Timeline view: draw a rectangular zone on the map, then read the temporal
// "fresco" of every finding inside that zone that also passes the active
// filters (label / confidence / date range shared with the Live view).
Item {
    id: timelineView

    signal clipRequested(string path, string label)

    function selectFinding(index, recenter) {
        if (index < 0 || index >= FindingStore.count)
            return
        Selection.index = index
        detections.positionViewAt(index)
        if (recenter) {
            let item = FindingStore.get(index)
            map.centerOn(item.latitude, item.longitude)
        }
    }

    // Findings passing the filters AND inside the drawn zone, sorted by time.
    readonly property var events: {
        // Read every dependency so the binding re-evaluates on change: the
        // loop below may not run, and QML only captures what it actually reads.
        let arr = []
        for (let i = 0; i < FindingStore.count; i++) {
            let it = FindingStore.get(i)
            if (!FilterState.matches(it.label, it.confidence, it.timestamp))
                continue
            if (!tlMap.inZone(it.latitude, it.longitude))
                continue
            arr.push({ index: i, ts: it.timestamp,
                       label: it.label ? it.label : qsTr("Unlabeled"),
                       confidence: it.confidence, latitude: it.latitude,
                       longitude: it.longitude, videoPath: it.videoPath })
        }
        arr.sort(function (a, b) { return a.ts - b.ts })
        return arr
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingMd

        // ── Toolbar: filters + zone controls ────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            FilterBar {
                Layout.fillWidth: true
                expandButton: false
            }

            Item { Layout.fillWidth: !FilterState.active }

            ThemedButton {
                text: tlMap.drawMode ? qsTr("Drag on map…")
                    : (tlMap.hasZone ? qsTr("Redraw zone") : qsTr("Draw zone"))
                bgColor: tlMap.drawMode ? Theme.active : Theme.surface
                bgHover: Theme.surfaceHover
                contentColor: tlMap.drawMode ? Theme.backgroundDeep : Theme.text
                borderColor: tlMap.drawMode ? Theme.active : Theme.border
                onClicked: tlMap.drawMode = true
            }

            ThemedButton {
                visible: tlMap.hasZone
                text: qsTr("Clear zone")
                bgColor: Theme.dangerSurface
                bgHover: Theme.danger
                contentColor: Theme.danger
                contentHover: Theme.textOnAccent
                borderColor: Theme.danger
                onClicked: tlMap.clearZone()
            }
        }

        // ── Map (draw the zone here) ────────────────────────────────────
        Panel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 100 // grows; fresco below has a fixed height

            MapDisplay {
                id: tlMap
                anchors.fill: parent
                anchors.margins: 1

                onFindingClicked: function (index) { Selection.index = index }
            }

            // Hint shown while no zone is drawn.
            Rectangle {
                visible: !tlMap.hasZone && !tlMap.drawMode
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingMd
                radius: Theme.radiusPill
                color: Theme.overlay
                border.color: Theme.border
                border.width: 1
                implicitWidth: hintLabel.implicitWidth + 2 * Theme.spacingLg
                implicitHeight: 32

                Label {
                    id: hintLabel
                    anchors.centerIn: parent
                    text: qsTr("Draw a zone to focus the timeline")
                    color: Theme.textMuted
                    font.pixelSize: 12
                }
            }
        }

        // ── Temporal fresco ─────────────────────────────────────────────
        Panel {
            Layout.fillWidth: true
            Layout.preferredHeight: 240

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: qsTr("TIMELINE")
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                        color: Theme.textFaint
                        Layout.fillWidth: true
                    }
                    Label {
                        text: tlMap.hasZone
                            ? qsTr("%1 in zone").arg(timelineView.events.length)
                            : qsTr("%1 total").arg(timelineView.events.length)
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.textMuted
                    }
                }

                TimelineFresco {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    events: timelineView.events
                    emptyText: tlMap.hasZone
                        ? qsTr("No detections in this zone for the current filters.")
                        : qsTr("No detections match the current filters.")
                        
                    onSelectionRequested: function (index) { root.selectFinding(index, true) }

                    onEventActivated: function (finding) {
                        Selection.index = finding.index
                        tlMap.centerOn(finding.latitude, finding.longitude)
                        if (finding.videoPath)
                            timelineView.clipRequested(finding.videoPath, finding.label)
                    }
                }
            }
        }
    }
}
