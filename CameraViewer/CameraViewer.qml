import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: cameraViewer

    color: Theme.background
    border.color: Theme.surface
    border.width: 1
    radius: Theme.radiusLg
    clip: true

    Layout.alignment: Qt.AlignLeft
    width: parent.width

    CameraStreaming {
        id: camera
        anchors.fill: parent
        anchors.margins: 1

        Component.onCompleted: {
            camera.setSource(0)
            // camera.setSourcePath("tcp://xxx:8554")
            camera.startStream()
        }

        onPositionMocked: function(latitude, longitude, label, clipPath) {
            positionList.append({
                "latitude": latitude,
                "longitude": longitude,
                "label": label,
                "videoPath": clipPath
            })
        }
    }

    // Floating glassmorphism controls
    Rectangle {
        id: controlBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingXl
        width: 140
        height: 48
        radius: Theme.radiusPill
        color: Theme.overlay
        border.color: Theme.border
        border.width: 1
        z: 10 // Float over video stream

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingXs
            spacing: Theme.spacingSm

            Button {
                id: playBtn
                Layout.fillWidth: true
                Layout.fillHeight: true
                flat: true
                enabled: !camera.isRunning
                hoverEnabled: true

                contentItem: Text {
                    text: "▶"
                    font.pixelSize: 18
                    color: playBtn.enabled ? (playBtn.hovered ? Theme.accent : Theme.success)
                                           : Theme.textDisabled
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: playBtn.hovered ? Theme.surface : "transparent"
                    radius: 20
                }

                onClicked: camera.startStream()
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: Theme.spacingSm
                Layout.bottomMargin: Theme.spacingSm
                color: Theme.border
            }

            Button {
                id: stopBtn
                Layout.fillWidth: true
                Layout.fillHeight: true
                flat: true
                enabled: camera.isRunning
                hoverEnabled: true

                contentItem: Text {
                    text: "■"
                    font.pixelSize: 18
                    color: stopBtn.enabled ? (stopBtn.hovered ? "#fca5a5" : Theme.danger)
                                           : Theme.textDisabled
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: stopBtn.hovered ? Theme.surface : "transparent"
                    radius: 20
                }

                onClicked: camera.stopStream()
            }
        }
    }
}
