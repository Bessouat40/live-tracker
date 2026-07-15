pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

ApplicationWindow {
    id: mainWindow
    visible: true
    visibility: Window.Maximized
    title: qsTr("live-tracker")

    property string filter: ""
    property var uniqueLabels: []

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
    
    Plugin {
        id: mapPlugin
        name: "osm"
    }

    AddPositionPopup {
        id: addPositionPopup
        onPositionAdded: function(newLatitude, newLongitude, label) {
            positionList.append({latitude: parseFloat(newLatitude), longitude: parseFloat(newLongitude), label})
        }
    }

    Filters {
        id: positionFilters
        availableLabels: mainWindow.uniqueLabels
        
        onFilterSelected: function(selectedLabel) {
            mainWindow.filter = selectedLabel
            positionFilters.close()
        }
    }

    RowLayout {
        id: mainWindowLayout
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            id: positionListLayout
            Layout.preferredWidth: mainWindow.width / 3
            Layout.fillHeight: true
            spacing: 5

            RowLayout {
                Button {
                    text: "Add Position"
                    font.pointSize: 24
                    Layout.fillWidth: true
                    onClicked: addPositionPopup.open()
                }
                Button {
                    text: "Filter"
                    font.pointSize: 24
                    Layout.fillWidth: true
                    onClicked: positionFilters.open()
                }
            }


            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: mainWindow.height * 0.3
                clip: true

                ListView {
                    id: positionListViewer
                    model: positionList
                    spacing: 2
                    delegate: PositionItem {
                        width: positionListViewer.width
                        onRemoved: positionList.remove(index)
                    }
                }
            }

            MapDisplay {
                id: map
                Layout.fillWidth: true
                Layout.fillHeight: true 
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