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
            titles: [qsTr("Live"), qsTr("Timeline")]
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabStrip.currentIndex

            LiveView {
                onClipRequested: function (path, label) {
                    videoPopup.openWith(path, label)
                }
            }
            TimelineView {
                onClipRequested: function (path, label) {
                    videoPopup.openWith(path, label)
                }
            }
        }
    }
}
