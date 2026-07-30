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

    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: Theme.radiusLg
    }

    padding: Theme.spacingXxl

    property var availableLabels: []

    signal filterSelected(string selectedLabel)

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: Theme.spacingXl

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: qsTr("Filter by Label")
                font.pixelSize: 18
                font.bold: true
                color: Theme.text
                Layout.fillWidth: true
            }

            Button {
                id: closeBtn
                text: "✕"
                flat: true
                hoverEnabled: true
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32

                contentItem: Text {
                    text: closeBtn.text
                    color: closeBtn.hovered ? Theme.danger : Theme.textMuted
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: closeBtn.hovered ? Theme.surfaceHover : "transparent"
                    radius: 16
                }

                onClicked: positionFilters.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: Theme.spacingMd

                ButtonGroup {
                    id: radioGroup
                    onClicked: function(button) {
                        positionFilters.filterSelected(button.text)
                    }
                }

                Repeater {
                    model: positionFilters.availableLabels

                    delegate: RadioButton {
                        id: rBtn
                        required property string modelData
                        text: modelData
                        ButtonGroup.group: radioGroup
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        hoverEnabled: true

                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: rBtn.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            color: Theme.background
                            border.color: rBtn.checked ? Theme.accent
                                        : (rBtn.hovered ? Theme.textDisabled : Theme.border)
                            border.width: rBtn.checked ? 6 : 1
                        }

                        contentItem: Text {
                            text: rBtn.text
                            font: rBtn.font
                            color: rBtn.checked ? Theme.accent : Theme.text
                            leftPadding: rBtn.indicator.width + rBtn.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Label {
                    text: qsTr("No labels available")
                    visible: positionFilters.availableLabels.length === 0
                    font.italic: true
                    color: Theme.textFaint
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.spacingXl
                }
            }
        }

        ThemedButton {
            text: qsTr("Clear Filter")
            Layout.fillWidth: true
            bgColor: Theme.dangerSurface
            bgHover: Theme.danger
            contentColor: Theme.danger
            contentHover: Theme.textOnAccent
            borderColor: Theme.danger

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
