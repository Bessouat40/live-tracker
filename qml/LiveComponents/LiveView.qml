pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
    The "Live" tab: detections list and map on the left, camera on the right.
    Selection lives in the Selection singleton so the Timeline tab highlights
    the same finding; filter state lives in FilterState.
*/
Item {
    id: root

    property bool mapCentered: false

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

    Connections {
        target: FindingStore
        function onCountChanged() {
            // Bring the map to the tracked area on the very first finding,
            // otherwise the default centre may be nowhere near the pins.
            if (!root.mapCentered && FindingStore.count > 0) {
                root.mapCentered = true
                let first = FindingStore.get(0)
                map.centerOn(first.latitude, first.longitude)
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingMd

        ColumnLayout {
            id: sidePanel
            Layout.preferredWidth: root.width / 3
            Layout.fillHeight: true
            spacing: Theme.spacingLg

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: qsTr("Live Tracker")
                    font.pixelSize: 22
                    font.bold: true
                    color: Theme.text
                }
                Label {
                    text: FilterState.active
                        ? qsTr("%1 of %2 tracked").arg(FilterState.matchCount).arg(FindingStore.count)
                        : (FindingStore.count === 1
                            ? qsTr("1 detection tracked")
                            : qsTr("%1 detections tracked").arg(FindingStore.count))
                    font.pixelSize: 12
                    color: Theme.textMuted
                }
            }

            FilterBar {
                Layout.fillWidth: true
            }

            PanelSection {
                title: qsTr("DETECTIONS")
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: root.height * 0.25
                Layout.minimumHeight: 100

                DetectionsList {
                    id: detections
                    anchors.fill: parent
                    onSelectionRequested: function (index) { root.selectFinding(index, true) }
                    onRemoveRequested: function (index) {
                        FindingStore.remove(index)
                        Selection.clear()
                    }
                    onFindingClicked: function (index) { root.selectFinding(index, false) }
                    // onClipRequested: function (path, label) { root.clipRequested(path, label) }
                }
            }

            PanelSection {
                title: qsTr("MAP")
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: root.height * 0.6
                Layout.minimumHeight: 200

                MapDisplay {
                    id: map
                    anchors.fill: parent
                    anchors.margins: 1

                    onFindingClicked: function (index) { root.selectFinding(index, false) }
                }
            }
        }

        CameraViewer {
            id: cameraViewer
            Layout.fillHeight: true
            Layout.preferredWidth: 2 * root.width / 3
            Layout.fillWidth: true
        }
    }
}
