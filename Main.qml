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
    title: qsTr("geo-communication")

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
        Layout.fillWidth: true
        anchors.fill: parent
        spacing: 0
        ColumnLayout {
            id: positionListLayout
            width: mainWindow.width / 3
            Layout.alignment: Qt.AlignTop
            spacing: 0
            Button {
                text: "Add Position"
                font.pointSize: 24
                Layout.preferredWidth: positionListLayout.width
                onClicked: addPositionPopup.open()
            }
            Repeater {
                id: positionListViewer
                model: positionList
                width: positionListLayout.width
                PositionItem {
                    id: positionItem
                    onRemoved: positionList.remove(index)
                }
            }
        }

        Map {
            id: map
            plugin: mapPlugin
            Layout.fillWidth: true 
            Layout.fillHeight: true
            center: QtPositioning.coordinate(59.91, 10.75)
            zoomLevel: 14
            property geoCoordinate startCentroid

            PinchHandler {
                id: pinch
                target: null
                onActiveChanged: if (active) {
                    map.startCentroid = map.toCoordinate(pinch.centroid.position, false)
                }
                onScaleChanged: (delta) => {
                    map.zoomLevel += Math.log2(delta)
                    map.alignCoordinateToPoint(map.startCentroid, pinch.centroid.position)
                }
                onRotationChanged: (delta) => {
                    map.bearing -= delta
                    map.alignCoordinateToPoint(map.startCentroid, pinch.centroid.position)
                }
                grabPermissions: PointerHandler.TakeOverForbidden
            }
            WheelHandler {
                id: wheel
                // workaround for QTBUG-87646 / QTBUG-112394 / QTBUG-112432:
                // Magic Mouse pretends to be a trackpad but doesn't work with PinchHandler
                // and we don't yet distinguish mice and trackpads on Wayland either
                acceptedDevices: Qt.platform.pluginName === "cocoa" || Qt.platform.pluginName === "wayland"
                                ? PointerDevice.Mouse | PointerDevice.TouchPad
                                : PointerDevice.Mouse
                rotationScale: 1/120
                property: "zoomLevel"
            }
            DragHandler {
                id: drag
                target: null
                onTranslationChanged: (delta) => map.pan(-delta.x, -delta.y)
            }
            Shortcut {
                enabled: map.zoomLevel < map.maximumZoomLevel
                sequence: StandardKey.ZoomIn
                onActivated: map.zoomLevel = Math.round(map.zoomLevel + 1)
            }
            Shortcut {
                enabled: map.zoomLevel > map.minimumZoomLevel
                sequence: StandardKey.ZoomOut
                onActivated: map.zoomLevel = Math.round(map.zoomLevel - 1)
            }
        }
    }
}