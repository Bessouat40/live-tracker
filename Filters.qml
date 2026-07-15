import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: positionFilters
    modal: true
    focus: true
    
    width: Math.min(400, parent.width * 0.9)
    height: Math.min(600, contentLayout.implicitHeight + topPadding + bottomPadding)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2 

    padding: 20

    property var availableLabels: []

    signal filterSelected(string selectedLabel)

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            
            Label {
                text: qsTr("Filter by Label")
                font.pixelSize: 20
                font.bold: true
                Layout.fillWidth: true
            }
            
            ToolButton {
                text: "✕"
                font.pixelSize: 18
                onClicked: positionFilters.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#eeeeee"
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: 10

                ButtonGroup {
                    id: radioGroup
                    onClicked: function(button) {
                        positionFilters.filterSelected(button.text)
                    }
                }

                Repeater {
                    model: positionFilters.availableLabels

                    delegate: RadioButton {
                        text: modelData 
                        ButtonGroup.group: radioGroup 
                        font.pixelSize: 16
                        Layout.fillWidth: true
                    }
                }
                
                Label {
                    text: qsTr("No label available")
                    visible: positionFilters.availableLabels.length === 0
                    font.italic: true
                    color: "#888888"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                }
            }
        }

        Button {
            text: qsTr("Clear Filter")
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            
            contentItem: Text {
                text: parent.text
                font.pixelSize: 16
                font.bold: true
                color: parent.down ? "#ffffff" : "#d32f2f"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Rectangle {
                color: parent.down ? "#d32f2f" : "#ffebee"
                radius: 8
                border.color: "#d32f2f"
                border.width: 1
            }

            onClicked: {
                if (radioGroup.checkedButton) {
                    radioGroup.checkedButton.checked = false
                }
                
                positionFilters.filterSelected("")
                positionFilters.close()
            }
        }
    }
}