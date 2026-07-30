import QtQuick
import QtQuick.Controls
import QtMultimedia

Popup {
    id: root
    modal: true
    focus: true
    dim: true
    padding: 0

    width: Math.min(880, parent.width * 0.8)
    height: width * 9 / 16
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    property string title: ""

    function openWith(url, label) {
        root.title = label
        player.source = url
        open()
        player.play()
    }

    onClosed: player.stop()

    background: Rectangle {
        color: Theme.background
        border.color: Theme.border
        border.width: 1
        radius: Theme.radiusLg
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        radius: Theme.radiusLg
        clip: true

        VideoOutput {
            id: vout
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
        }

        MediaPlayer {
            id: player
            videoOutput: vout
            loops: MediaPlayer.Infinite
        }

        // Click to toggle play/pause
        MouseArea {
            anchors.fill: parent
            onClicked: player.playbackState === MediaPlayer.PlayingState
                       ? player.pause()
                       : player.play()
        }

        // Title chip
        Rectangle {
            visible: root.title !== ""
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Theme.spacingSm
            width: titleLabel.implicitWidth + 2 * Theme.spacingMd
            height: 28
            radius: Theme.radiusSm
            color: Theme.overlay
            border.color: Theme.border
            border.width: 1

            Label {
                id: titleLabel
                anchors.centerIn: parent
                text: root.title
                color: Theme.text
                font.pixelSize: 12
                font.bold: true
            }
        }

        // Play indicator when paused
        Rectangle {
            anchors.centerIn: parent
            width: 64
            height: 64
            radius: 32
            color: Theme.overlay
            border.color: Theme.border
            border.width: 1
            visible: player.playbackState !== MediaPlayer.PlayingState

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 3
                text: "▶"
                font.pixelSize: 26
                color: Theme.text
            }
        }

        // Close button
        Button {
            id: closeBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingSm
            flat: true
            hoverEnabled: true
            width: 32
            height: 32

            contentItem: Text {
                text: "✕"
                color: closeBtn.hovered ? Theme.danger : Theme.text
                font.pixelSize: 15
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 16
                color: closeBtn.hovered ? Theme.surfaceHover : Theme.overlay
            }
            onClicked: root.close()
        }
    }
}
