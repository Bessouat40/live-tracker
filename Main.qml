pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: mainWindow
    visible: true
    visibility: Window.Maximized
    title: qsTr("live-tracker")
    color: Theme.backgroundDeep

    function selectFinding(index, recenter) {
        if (index < 0 || index >= FindingStore.count)
            return
        Selection.index = index
        liveView.positionViewAt(index)
        if (recenter) {
            let item = FindingStore.get(index)
            liveView.centerOn(item.latitude, item.longitude)
        }
    }

    // Single instance, opened on request by either tab.
    VideoPopup {
        id: videoPopup
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabStrip {
            id: tabStrip
            Layout.fillWidth: true
            titles: [qsTr("Live"), qsTr("Timeline"), qsTr("Video Analysis")]
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabStrip.currentIndex

            LiveView {
                id: liveView
                onClipRequested: function (path, label) {
                    videoPopup.openWith(path, label)
                }
                onSelectFinding: function (index) { mainWindow.selectFinding(index, true) }
            }
            TimelineView {
                onClipRequested: function (path, label) {
                    videoPopup.openWith(path, label)
                }
                onSelectFinding: function (index) { mainWindow.selectFinding(index, true) }
            }
            VideoAnalysisView {
            }
        }
    }
}
