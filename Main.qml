pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation

ApplicationWindow {
    id: mainWindow
    visible: true
    visibility: Window.Maximized
    title: qsTr("live-tracker")
    color: Theme.backgroundDeep

    property string filter: ""
    property var uniqueLabels: []
    property int selectedIndex: -1

    ListModel {
        id: positionList
        onCountChanged: mainWindow.updateLabels()
    }

    function updateLabels() {
        let labels = [];
        for (let i = 0; i < positionList.count; i++) {
            let item = positionList.get(i);
            if (item.label && labels.indexOf(item.label) === -1) {
                labels.push(item.label);
            }
        }
        mainWindow.uniqueLabels = labels;
    }

    function selectFinding(index, recenter) {
        if (index < 0 || index >= positionList.count)
            return;
        mainWindow.selectedIndex = index;
        positionListViewer.positionViewAtIndex(index, ListView.Contain);
        if (recenter) {
            let item = positionList.get(index);
            map.centerOn(item.latitude, item.longitude);
        }
    }

    Plugin {
        id: mapPlugin
        name: "osm"
    }

    Filters {
        id: positionFilters
        availableLabels: mainWindow.uniqueLabels

        onFilterSelected: function(selectedLabel) {
            mainWindow.filter = selectedLabel
            positionFilters.close()
        }
    }

    VideoPopup {
        id: videoPopup
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingMd

        ColumnLayout {
            id: sidePanel
            Layout.preferredWidth: mainWindow.width / 3
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
                    text: positionList.count === 1
                        ? qsTr("1 detection tracked")
                        : qsTr("%1 detections tracked").arg(positionList.count)
                    font.pixelSize: 12
                    color: Theme.textMuted
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                ThemedButton {
                    text: qsTr("Filter")
                    Layout.fillWidth: mainWindow.filter === ""
                    bgColor: Theme.accentStrong
                    bgHover: Theme.accent
                    contentColor: Theme.textOnAccent
                    borderColor: "transparent"
                    onClicked: positionFilters.open()
                }

                Rectangle {
                    visible: mainWindow.filter !== ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Theme.radiusMd
                    color: Theme.surface
                    border.color: Theme.accent
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingMd
                        anchors.rightMargin: Theme.spacingXs + 2
                        spacing: Theme.spacingXs + 2

                        Label {
                            text: qsTr("Filtered: %1").arg(mainWindow.filter)
                            color: Theme.accent
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Button {
                            id: clearChip
                            flat: true
                            hoverEnabled: true
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28

                            contentItem: Text {
                                text: "✕"
                                color: clearChip.hovered ? Theme.danger : Theme.textMuted
                                font.pixelSize: 13
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: 14
                                color: clearChip.hovered ? Theme.surfaceHover : "transparent"
                            }
                            onClicked: mainWindow.filter = ""
                        }
                    }
                }
            }

            Label {
                text: qsTr("DETECTIONS")
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
                color: Theme.textFaint
                Layout.bottomMargin: -Theme.spacingSm
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: mainWindow.height * 0.25
                Layout.minimumHeight: 100
                radius: Theme.radiusLg
                color: Theme.background
                border.color: Theme.surface
                border.width: 1
                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSm
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ListView {
                        id: positionListViewer
                        model: positionList
                        spacing: Theme.spacingSm
                        delegate: PositionItem {
                            width: positionListViewer.width
                            onRemoved: {
                                positionList.remove(index)
                                mainWindow.selectedIndex = -1
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width - 2 * Theme.spacingLg
                    visible: positionList.count === 0
                    text: qsTr("No detections yet.\nStart the stream to begin tracking.")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.italic: true
                }
            }

            Label {
                text: qsTr("MAP")
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
                color: Theme.textFaint
                Layout.bottomMargin: -Theme.spacingSm
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: mainWindow.height * 0.6
                Layout.minimumHeight: 200
                radius: Theme.radiusLg
                color: Theme.background
                border.color: Theme.surface
                border.width: 1
                clip: true

                MapDisplay {
                    id: map
                    anchors.fill: parent
                    anchors.margins: 1
                }
            }
        }

        CameraViewer {
            id: cameraViewer
            Layout.fillHeight: true
            Layout.preferredWidth: 2 * mainWindow.width / 3
            Layout.fillWidth: true
        }
    }
}
