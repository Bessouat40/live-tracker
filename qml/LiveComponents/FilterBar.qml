pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
    "Filter" button, active-filter chip, and the popup behind them. Self
    contained: it reads and writes FilterState, so a view only has to place it.
*/
RowLayout {
    id: root

    // Let the button take the whole width when no filter is set. Views that
    // put controls to the right of the bar set this to false.
    property bool expandButton: true

    spacing: Theme.spacingSm

    Filters {
        id: filtersPopup
        availableLabels: FilterState.availableLabels
        currentLabel: FilterState.label
        currentMinConfidence: FilterState.minConfidence
        currentFrom: FilterState.fromMs
        currentTo: FilterState.toMs

        onFiltersApplied: function (label, minConfidence, fromMs, toMs) {
            FilterState.apply(label, minConfidence, fromMs, toMs)
            filtersPopup.close()
        }
    }

    ThemedButton {
        text: FilterState.active ? qsTr("Edit filters") : qsTr("Filter")
        Layout.fillWidth: root.expandButton && !FilterState.active
        bgColor: Theme.accentStrong
        bgHover: Theme.accent
        contentColor: Theme.textOnAccent
        borderColor: "transparent"
        onClicked: filtersPopup.open()
    }

    Rectangle {
        visible: FilterState.active
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: Theme.radiusMd
        color: Theme.surface
        border.color: Theme.accent
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingMd
            anchors.rightMargin: Theme.spacingXs + 2
            spacing: Theme.spacingXs + 2

            Label {
                text: FilterState.summary()
                color: Theme.accent
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Button {
                id: clearChip
                flat: true
                hoverEnabled: true
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                contentItem: Text {
                    text: "✕"
                    color: clearChip.hovered ? Theme.danger : Theme.textMuted
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 14
                    color: clearChip.hovered ? Theme.surfaceHover : "transparent"
                }
                onClicked: FilterState.clear()
            }
        }
    }
}
