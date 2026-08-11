pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
    Source selector for the live camera: local webcam or a custom stream URL.
    Emits sourceRequested() once the user has picked something usable.
*/
RowLayout {
    id: root

    readonly property string sourceKind: sourceCombo.currentValue
    readonly property bool isCustom: sourceKind === "url"
    readonly property string sourceUrl: urlField.text.trim()

    signal sourceRequested(string kind, string url)

    spacing: Theme.spacingMd

    Label {
        text: qsTr("SOURCE")
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1
        color: Theme.textMuted
    }

    ComboBox {
        id: sourceCombo
        textRole: "label"
        valueRole: "value"
        implicitWidth: 140

        model: ListModel {
            ListElement { label: qsTr("Webcam"); value: "webcam" }
            ListElement { label: qsTr("Custom URL"); value: "url" }
        }

        // Switching back to the webcam needs no confirmation, apply directly.
        onActivated: if (!root.isCustom) root.apply()

        Component.onCompleted: {
            currentIndex = 0
            root.apply()
        }
    }

    TextField {
        id: urlField
        visible: root.isCustom
        Layout.fillWidth: true
        placeholderText: qsTr("rtsp://…  or  http://…/stream.mjpg")
        selectByMouse: true
        color: Theme.text
        onAccepted: root.apply()
    }

    Button {
        visible: root.isCustom
        text: qsTr("Connect")
        enabled: root.sourceUrl.length > 0
        onClicked: root.apply()
    }

    // Fill the gap so the combo stays left-aligned in webcam mode.
    Item {
        visible: !root.isCustom
        Layout.fillWidth: true
    }

    function apply() {
        if (root.isCustom && root.sourceUrl.length === 0)
            return
        root.sourceRequested(root.sourceKind, root.isCustom ? root.sourceUrl : "")
    }
}