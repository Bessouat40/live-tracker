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

    ListModel {
        id: positionList
    }
    
    Plugin {
        id: mapPlugin
        name: "osm"
    }

    AddPositionPopup {
        id: addPositionPopup
        onPositionAdded: function(newLatitude, newLongitude) {
            console.log("Adding position: " + newLatitude + ", " + newLongitude)
            positionList.append({latitude: parseFloat(newLatitude), longitude: parseFloat(newLongitude)})
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

            Button {
                text: "Add Position"
                font.pointSize: 24
                Layout.fillWidth: true
                onClicked: addPositionPopup.open()
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
        CameraStreaming {
            id: camera
            
            Layout.fillHeight: true
            Layout.preferredWidth: 2 * mainWindow.width / 3
            Layout.fillWidth: true
            
            Component.onCompleted: {
                // camera.setSource(0) 
                camera.setSourcePath("media/test.mp4")
                camera.startStream()
            }
        }
    }
}