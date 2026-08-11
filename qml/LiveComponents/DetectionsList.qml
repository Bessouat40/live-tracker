pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
    Scrollable list of findings plus its empty state. Meant to be dropped into
    a PanelSection with anchors.fill: parent.
*/
Item {
    id: root

    signal selectionRequested(int index)
    signal removeRequested(int index)
    signal findingClicked(int index)

    function positionViewAt(index) {
        list.positionViewAtIndex(index, ListView.Contain)
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: Theme.spacingSm
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ListView {
            id: list
            model: FindingStore
            spacing: Theme.spacingSm

            delegate: PositionItem {
                width: list.width

                // Wire these up if PositionItem exposes them:
                // selected: index === Selection.index
                // onClicked: root.selectionRequested(index)

                onRemoved: root.removeRequested(index)
                onFindingClicked: root.findingClicked(index)
            }
        }
    }

    Label {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.spacingLg
        visible: FindingStore.count === 0
        text: qsTr("No detections yet.\nStart the stream to begin tracking.")
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: Theme.textFaint
        font.pixelSize: 12
        font.italic: true
    }
}
