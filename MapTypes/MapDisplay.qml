pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

Map {
    id: map
    plugin: mapPlugin
    center: QtPositioning.coordinate(59.91, 10.75)
    zoomLevel: 14
    property geoCoordinate startCentroid
    property int activeIndex: -1
    function setActive(active, latitude, longitude, index) {
        if (active) {
            map.activeIndex = index
            map.center = QtPositioning.coordinate(latitude, longitude)
            map.zoomLevel = 16
        } else {
            map.activeIndex = -1
        }
    }

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

    MapItemView {
        model: positionList
        delegate: MapCircle {
            required property int index
            required property real latitude
            required property real longitude

            center: QtPositioning.coordinate(latitude, longitude)
            
            radius: 10.0 
            color: map.activeIndex === index ? 'yellow' : 'green'
            border.color: 'black'
            border.width: 3

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true // Ici, la propriété existe bien !

                ToolTip {
                    // On affiche le ToolTip quand la souris survole le MouseArea
                    visible: parent.containsMouse
                    
                    text: "Lat: " + latitude.toFixed(4) + "\nLon: " + longitude.toFixed(4)
                    delay: 100 
                }
            }
        }
    }
}