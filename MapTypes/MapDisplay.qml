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

    // ── Geographic zone (optional, used by the Timeline view) ───────────
    // When drawMode is true, dragging on the map traces a rectangular zone
    // instead of panning. hasZone flags an active zone; z* are its bounds.
    property bool drawMode: false
    property bool hasZone: false
    property double zMinLat: 0
    property double zMaxLat: 0
    property double zMinLon: 0
    property double zMaxLon: 0

    signal zoneChanged()

    function inZone(lat, lon) {
        if (!map.hasZone)
            return true
        return lat >= map.zMinLat && lat <= map.zMaxLat
            && lon >= map.zMinLon && lon <= map.zMaxLon
    }

    function clearZone() {
        map.hasZone = false
        map.zMinLat = 0; map.zMaxLat = 0; map.zMinLon = 0; map.zMaxLon = 0
        map.zoneChanged()
    }

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

    // Visible zone rectangle. topLeft = (north, west), bottomRight = (south, east).
    MapRectangle {
        id: zoneRect
        visible: map.hasZone
        topLeft: QtPositioning.coordinate(map.zMaxLat, map.zMinLon)
        bottomRight: QtPositioning.coordinate(map.zMinLat, map.zMaxLon)
        color: "#2638bdf8"
        border.color: Theme.accent
        border.width: 2
    }

    MapItemView {
        model: positionList
        delegate: MapQuickItem {
            id: pin
            required property int index
            required property real latitude
            required property real longitude
            required property string label
            required property double confidence
            required property double timestamp

            coordinate: QtPositioning.coordinate(latitude, longitude)
            anchorPoint.x: 16
            anchorPoint.y: 32
            visible: mainWindow.matchesFilters(pin.label, pin.confidence, pin.timestamp)

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
                        + (pin.confidence > 0 ? "<br>Conf: " + Math.round(pin.confidence * 100) + "%" : "")
                        + "<br>" + mainWindow.timeAgo(pin.timestamp)

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

    // Drag-to-draw overlay. Only active in drawMode, so normal pan/zoom is
    // untouched otherwise. Screen points are converted to map coordinates.
    MouseArea {
        id: drawArea
        anchors.fill: parent
        enabled: map.drawMode
        visible: map.drawMode
        cursorShape: Qt.CrossCursor
        preventStealing: true
        z: 1000

        property point startPt
        property bool dragging: false

        onPressed: (mouse) => {
            drawArea.startPt = Qt.point(mouse.x, mouse.y)
            drawArea.dragging = true
            let c = map.toCoordinate(drawArea.startPt, false)
            map.zMinLat = c.latitude; map.zMaxLat = c.latitude
            map.zMinLon = c.longitude; map.zMaxLon = c.longitude
            map.hasZone = true
        }

        onPositionChanged: (mouse) => {
            if (!drawArea.dragging)
                return
            let c1 = map.toCoordinate(drawArea.startPt, false)
            let c2 = map.toCoordinate(Qt.point(mouse.x, mouse.y), false)
            map.zMinLat = Math.min(c1.latitude, c2.latitude)
            map.zMaxLat = Math.max(c1.latitude, c2.latitude)
            map.zMinLon = Math.min(c1.longitude, c2.longitude)
            map.zMaxLon = Math.max(c1.longitude, c2.longitude)
        }

        onReleased: (mouse) => {
            drawArea.dragging = false
            map.drawMode = false
            // Discard accidental clicks / zero-size zones.
            if (map.zMaxLat - map.zMinLat < 1e-6 && map.zMaxLon - map.zMinLon < 1e-6)
                map.clearZone()
            else
                map.zoneChanged()
        }
    }
}
