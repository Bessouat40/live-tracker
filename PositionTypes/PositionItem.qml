import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: positionItem
    required property int index
    required property string label
    required property real latitude
    required property real longitude
    required property string videoPath

    readonly property bool selected: mainWindow.selectedIndex === positionItem.index

    color: selected ? Theme.surfaceHover : Theme.surface
    border.color: selected ? Theme.accent : Theme.border
    border.width: 1
    radius: Theme.radiusMd

    Layout.alignment: Qt.AlignLeft
    width: parent.width

    readonly property bool isMatch: mainWindow.filter === "" || label.includes(mainWindow.filter)
    visible: isMatch
    height: isMatch ? 64 : 0

    clip: true

    signal removed()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingMd
        spacing: Theme.spacingMd

        // Status dot
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            radius: 5
            color: positionItem.selected ? Theme.active : Theme.accent
        }

        // Label + coordinates
        ColumnLayout {
            spacing: Theme.spacingXs
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            Label {
                text: positionItem.label ? positionItem.label : qsTr("Unlabeled Position")
                font.pixelSize: 13
                font.bold: true
                color: Theme.text
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Label {
                text: "Lat: " + positionItem.latitude.toFixed(5) + "  Lon: " + positionItem.longitude.toFixed(5)
                font.pixelSize: 11
                color: Theme.textMuted
                Layout.fillWidth: true
            }
        }

        // Play evidence clip
        Button {
            id: playButton
            visible: positionItem.videoPath !== ""
            flat: true
            hoverEnabled: true
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter

            background: Rectangle {
                color: playButton.hovered ? Theme.surfaceHover : "transparent"
                radius: 18
            }

            contentItem: Text {
                text: "▶"
                font.pixelSize: 13
                color: playButton.hovered ? Theme.accent : Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: videoPopup.openWith(positionItem.videoPath, positionItem.label)
        }

        // Focus map
        Button {
            id: focusButton
            flat: true
            hoverEnabled: true
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter

            background: Rectangle {
                color: focusButton.hovered ? Theme.surfaceHover : "transparent"
                radius: 18
            }

            contentItem: Image {
                source: "../icons/eye-solid-full.svg"
                sourceSize.width: 16
                sourceSize.height: 16
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter
                opacity: focusButton.hovered ? 1.0 : 0.8
            }

            onClicked: mainWindow.selectFinding(positionItem.index, true)
        }

        // Delete
        Button {
            id: deleteButton
            text: "✕"
            flat: true
            hoverEnabled: true
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter

            contentItem: Text {
                text: deleteButton.text
                font.pixelSize: 14
                font.bold: true
                color: deleteButton.hovered ? Theme.danger : Theme.textFaint
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: deleteButton.hovered ? Theme.dangerSurface : "transparent"
                radius: 18
                border.color: deleteButton.hovered ? Theme.danger : "transparent"
                border.width: deleteButton.hovered ? 1 : 0
            }

            onClicked: positionItem.removed()
        }
    }
}
