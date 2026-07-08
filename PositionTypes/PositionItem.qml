import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: positionItem
    required property int index
    required property real latitude
    required property real longitude

    color: (index % 2) == 0 ? "dimgray" : "lightgray"
    Layout.alignment: Qt.AlignLeft
    width: parent.width
    height: positionLabel.height + 30
    signal removed()
    RowLayout {
        spacing: 30
        width: parent.width
        anchors.left: parent.left
        anchors.right: parent.right
        
        anchors.verticalCenter: parent.verticalCenter
        
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        Label {
            id: positionLabel
            text: latitude + ", " + longitude
            Layout.fillWidth: true
        }
        RoundButton {
            id: deletePositionButton
            text: "x"
            font.pointSize: 12
            palette.buttonText: "red"
            onClicked: removed(index)
        }
    }
}
