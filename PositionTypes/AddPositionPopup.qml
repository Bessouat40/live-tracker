import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: addPositionPopup
    modal: true
    focus: true
    width: parent.width * 0.9
    x: (parent.width - width) / 2
    y: 35
    onOpened: {
        latitude.text = "";
        longitude.text = "";
        latitude.focus = true;
    }

    signal positionAdded(string newLatitude, string newLongitude)

    ColumnLayout {
        anchors.fill: parent
        spacing: 15

        ColumnLayout {
            TextField {
                id: latitude
                placeholderText: qsTr("Latitude")
                font.pointSize: 24
                Layout.preferredWidth: addPositionPopup.width / 2
                Layout.fillWidth: true
            }
            TextField {
                id: longitude
                placeholderText: qsTr("Longitude")
                font.pointSize: 24
                Layout.preferredWidth: addPositionPopup.width / 2
                Layout.fillWidth: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Button {
                text: "Add"
                enabled: latitude.length > 0 && longitude.length > 0
                font.pointSize: 24
                Layout.preferredWidth: addPositionPopup.width / 2
                Layout.fillWidth: true
                onClicked: {
                    addPositionPopup.positionAdded(latitude.text, longitude.text)
                    addPositionPopup.close()
                }
            }
            Button {
                text: "Cancel"
                font.pointSize: 24
                Layout.preferredWidth: addPositionPopup.width / 2
                Layout.fillWidth: true
                onClicked: addPositionPopup.close()
            }
        }
    }
}