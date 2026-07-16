import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

Rectangle {
    id: cameraViewer

    color: "dimgray"
    Layout.alignment: Qt.AlignLeft
    width: parent.width
    signal removed()
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 5
        RowLayout {
            spacing: 30
            width: parent.width
            Layout.alignment: Qt.AlignHCenter
            Button {
                id: playButton
                text: "▶"
                enabled: !camera.isRunning
                font.pointSize: 24                
                flat: true
                onClicked: {
                    camera.startStream()
                }
            }
            Button {
                id: stopButton
                text: "■"
                enabled: camera.isRunning
                font.pointSize: 24
                flat: true
                palette.buttonText: enabled ? "red" : "gray"
                onClicked: {
                    camera.stopStream()
                }
            }
        }
        CameraStreaming {
            id: camera
            
            Layout.fillHeight: true
            Layout.preferredWidth: 2 * mainWindow.width / 3
            Layout.fillWidth: true
            
            Component.onCompleted: {
                // camera.setSource(0) 
                camera.setSourcePath("media/test.mp4")
                camera.startStream()
            }

            onPositionMocked: function(latitude, longitude, label) {
                positionList.append({
                    "latitude": latitude, 
                    "longitude": longitude,
                    "label": label
                })
            }
        }
    }
}
