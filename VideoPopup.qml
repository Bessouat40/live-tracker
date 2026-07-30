import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
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
    property url clipUrl: ""
    property string saveStatus: ""

    function openWith(url, label) {
        root.title = label
        root.clipUrl = url
        root.saveStatus = ""
        player.source = url
        open()
        player.play()
    }

    function suggestedName() {
        let base = root.title ? root.title.replace(/[^\w\-]+/g, "_") : "finding"
        return "clip_" + base + "_" + Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss") + ".mp4"
    }

    onClosed: player.stop()

    FileDialog {
        id: saveDialog
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("MP4 video (*.mp4)")]
        defaultSuffix: "mp4"
        onAccepted: {
            let ok = FindingStore.exportClip(root.clipUrl, saveDialog.selectedFile)
            root.saveStatus = ok ? qsTr("Saved ✓") : qsTr("Save failed")
            saveStatusTimer.restart()
        }
    }

    Timer {
        id: saveStatusTimer
        interval: 2800
        onTriggered: root.saveStatus = ""
    }

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

        // Top-right controls: save clip + close
        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingSm
            spacing: Theme.spacingSm

            // Transient save-status chip
            Rectangle {
                visible: root.saveStatus !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: statusLabel.implicitWidth + 2 * Theme.spacingMd
                height: 28
                radius: Theme.radiusSm
                color: Theme.overlay
                border.color: root.saveStatus === qsTr("Save failed") ? Theme.danger : Theme.success
                border.width: 1

                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: root.saveStatus
                    color: root.saveStatus === qsTr("Save failed") ? Theme.danger : Theme.success
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            // Save / download clip
            Button {
                id: saveBtn
                visible: root.clipUrl.toString() !== ""
                flat: true
                hoverEnabled: true
                width: 72
                height: 32

                contentItem: Text {
                    text: "⤓ " + qsTr("Save")
                    color: saveBtn.hovered ? Theme.accent : Theme.text
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 16
                    color: saveBtn.hovered ? Theme.surfaceHover : Theme.overlay
                    border.color: Theme.border
                    border.width: 1
                }
                onClicked: {
                    saveDialog.currentFolder = StandardPaths.writableLocation(StandardPaths.MoviesLocation)
                    saveDialog.selectedFile = StandardPaths.writableLocation(StandardPaths.MoviesLocation)
                        + "/" + root.suggestedName()
                    saveDialog.open()
                }
            }

            // Close button
            Button {
                id: closeBtn
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
}
