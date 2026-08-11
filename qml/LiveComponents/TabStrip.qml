pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property var titles: []
    property int currentIndex: 0

    implicitHeight: 48
    color: Theme.background

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingLg
        spacing: Theme.spacingXl

        Repeater {
            model: root.titles

            delegate: Item {
                id: tabItem
                required property int index
                required property string modelData

                readonly property bool current: root.currentIndex === tabItem.index

                // Width is measured on the bold text whatever the state:
                // sizing the layout from tabText.implicitWidth instead
                // couples it to font.bold, which the click itself flips.
                // That loop leaves the item — and its MouseArea — with a
                // stale width, so clicks land outside the hit area.
                TextMetrics {
                    id: tabMetrics
                    text: tabItem.modelData
                    font.pixelSize: 14
                    font.bold: true
                }

                implicitWidth: tabMetrics.width + 2 * Theme.spacingMd
                Layout.preferredWidth: implicitWidth
                Layout.fillHeight: true

                Label {
                    id: tabText
                    anchors.centerIn: parent
                    text: tabItem.modelData
                    font.pixelSize: 14
                    font.bold: tabItem.current
                    color: tabItem.current ? Theme.text : Theme.textMuted
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    radius: 1
                    color: Theme.accent
                    visible: tabItem.current
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentIndex = tabItem.index
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.surface
    }
}
