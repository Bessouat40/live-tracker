import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
    A small-caps section title above a Panel.

    Children declared inside are reparented into the frame, so they should
    anchor themselves:

        PanelSection {
            title: qsTr("MAP")
            MapDisplay { anchors.fill: parent }
        }
*/
ColumnLayout {
    id: root

    property string title: ""
    default property alias content: frame.data

    spacing: Theme.spacingSm

    Label {
        text: root.title
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1
        color: Theme.textFaint
    }

    Panel {
        id: frame
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}
