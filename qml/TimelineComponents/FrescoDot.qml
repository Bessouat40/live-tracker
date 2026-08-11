pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// One detection on the fresco. Positioned by the fresco, sized by its state.
Rectangle {
    id: dot

    property var finding: null
    property color laneColor: Theme.text

    signal activated()

    readonly property bool selected: finding !== null && Selection.index === finding.index
    readonly property bool hasClip: finding !== null && !!finding.videoPath

    width: selected ? 14 : 10
    height: width
    radius: width / 2
    color: laneColor
    border.color: selected ? Theme.text : Theme.background
    border.width: selected ? 2 : 1
    z: selected ? 10 : 1

    // Ring marking dots that carry an evidence clip.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 6
        height: width
        radius: width / 2
        color: "transparent"
        border.color: Theme.text
        border.width: 1.5
        opacity: 0.45
        visible: dot.hasClip && !dot.selected
    }

    MouseArea {
        id: dotMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: dot.activated()

        ToolTip {
            id: dotTip
            visible: dotMouse.containsMouse
            delay: 100
            text: "<b>" + dot.finding.label + "</b><br>"
                + Qt.formatDateTime(new Date(dot.finding.ts), "dd MMM HH:mm:ss")
                + (dot.finding.confidence > 0
                    ? "<br>Conf: " + Math.round(dot.finding.confidence * 100) + "%" : "")
                + (dot.hasClip ? "<br>▶ " + qsTr("click to play clip")
                               : "<br><i>" + qsTr("no clip") + "</i>")
            background: Rectangle {
                color: Theme.overlay
                border.color: Theme.border
                border.width: 1
                radius: Theme.radiusSm
            }
            contentItem: Text {
                text: dotTip.text
                color: Theme.text
                font.pixelSize: 11
                textFormat: Text.RichText
            }
        }
    }
}
