pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning

Map {
    id: map
    plugin: mapPlugin
    center: QtPositioning.coordinate(59.91, 10.75)
    zoomLevel: 14
    property geoCoordinate startCentroid

    function centerOn(latitude, longitude) {
        map.center = QtPositioning.coordinate(latitude, longitude)
        map.zoomLevel = 16
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
        delegate: MapQuickItem {
            id: pin
            required property int index
            required property real latitude
            required property real longitude
            required property string label

            coordinate: QtPositioning.coordinate(latitude, longitude)
            anchorPoint.x: 16
            anchorPoint.y: 32

            sourceItem: Item {
                width: 32
                height: 32

                // Pin head
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2
                    width: 24
                    height: 24
                    radius: 12
                    color: mainWindow.selectedIndex === pin.index ? Theme.active : Theme.accentStrong
                    border.color: Theme.textOnAccent
                    border.width: 2

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.background
                    }
                }

                // Pin tip
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 16
                    width: 10
                    height: 10
                    color: mainWindow.selectedIndex === pin.index ? Theme.active : Theme.accentStrong
                    rotation: 45
                    z: -1
                }
            }

            MouseArea {
                id: pinMouse
                anchors.fill: parent
                hoverEnabled: true

                onClicked: mainWindow.selectFinding(pin.index, false)

                ToolTip {
                    id: pinTip
                    visible: pinMouse.containsMouse
                    delay: 100

                    text: (pin.label ? "<b>" + pin.label + "</b><br>" : "")
                        + "Lat: " + pin.latitude.toFixed(5) + "<br>Lon: " + pin.longitude.toFixed(5)

                    background: Rectangle {
                        color: Theme.overlay
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.radiusSm
                    }

                    contentItem: Text {
                        text: pinTip.text
                        color: Theme.text
                        font.pixelSize: 11
                        textFormat: Text.RichText
                    }
                }
            }
        }
    }
}
