pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Reusable text button styled from the Theme palette.
// Override the color roles for accent / danger / neutral variants.
Button {
    id: control

    hoverEnabled: true
    font.pixelSize: 14
    font.bold: true
    implicitHeight: 40

    property color bgColor: Theme.surface
    property color bgHover: Theme.surfaceHover
    property color contentColor: Theme.text
    property color contentHover: contentColor
    property color borderColor: Theme.border

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? (control.hovered ? control.contentHover : control.contentColor)
                               : Theme.textDisabled
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radiusMd
        color: !control.enabled ? Theme.surface
             : control.down     ? Qt.darker(control.bgColor, 1.15)
             : control.hovered  ? control.bgHover
             : control.bgColor
        border.color: control.enabled ? control.borderColor : Theme.border
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
