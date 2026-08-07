pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation

ApplicationWindow {
    id: mainWindow
    visible: true
    visibility: Window.Maximized
    title: qsTr("live-tracker")
    color: Theme.backgroundDeep

    Component.onCompleted: mainWindow.updateLabels()

    property int currentTab: 0
    property string filter: ""
    property real minConfidence: 0
    property double filterFrom: 0 // epoch ms lower bound; 0 = unbounded
    property double filterTo: 0   // epoch ms upper bound; 0 = unbounded
    property var uniqueLabels: []
    property int selectedIndex: -1

    readonly property bool hasActiveFilter: filter !== "" || minConfidence > 0 || filterFrom > 0 || filterTo > 0

    // Number of findings currently passing the active filters.
    readonly property int filteredCount: {
        let deps = [filter, minConfidence, filterFrom, filterTo, positionList.count]
        let c = 0
        for (let i = 0; i < positionList.count; i++) {
            let it = positionList.get(i)
            if (matchesFilters(it.label, it.confidence, it.timestamp))
                c++
        }
        return c
    }

    function matchesFilters(label, confidence, timestamp) {
        // Exact match: the filter comes from a radio button listing existing
        // labels, so "car" must not also select "caravan".
        if (filter !== "" && label !== filter)
            return false
        if (confidence < minConfidence)
            return false
        if (filterFrom > 0 && timestamp < filterFrom)
            return false
        if (filterTo > 0 && timestamp > filterTo)
            return false
        return true
    }

    function dateRangeLabel() {
        let f = filterFrom > 0 ? Qt.formatDateTime(new Date(filterFrom), "dd MMM HH:mm") : ""
        let t = filterTo > 0 ? Qt.formatDateTime(new Date(filterTo), "dd MMM HH:mm") : ""
        if (f && t)
            return f + " → " + t
        if (f)
            return qsTr("from ") + f
        return qsTr("until ") + t
    }

    function filterSummary() {
        let parts = []
        if (filter !== "")
            parts.push(filter)
        if (minConfidence > 0)
            parts.push("≥" + Math.round(minConfidence * 100) + "%")
        if (filterFrom > 0 || filterTo > 0)
            parts.push(dateRangeLabel())
        return parts.join("  ·  ")
    }

    function clearFilters() {
        filter = ""
        minConfidence = 0
        filterFrom = 0
        filterTo = 0
    }

    // Persistent, SQLite-backed model of findings (single source of truth).
    readonly property var positionList: FindingStore

    // Ticks so relative timestamps ("2 min ago") stay fresh.
    property double now: Date.now()
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: mainWindow.now = Date.now()
    }

    Connections {
        target: FindingStore
        function onCountChanged() {
            mainWindow.updateLabels()
            // Bring the map to the tracked area on the very first finding,
            // otherwise the default centre may be nowhere near the pins.
            if (!mainWindow.mapCentered && positionList.count > 0) {
                mainWindow.mapCentered = true
                let first = positionList.get(0)
                map.centerOn(first.latitude, first.longitude)
            }
        }
    }

    property bool mapCentered: false

    function timeAgo(ts) {
        let diff = Math.max(0, (mainWindow.now - ts) / 1000)
        if (diff < 60)
            return qsTr("just now")
        if (diff < 3600)
            return qsTr("%1 min ago").arg(Math.floor(diff / 60))
        if (diff < 86400)
            return qsTr("%1 h ago").arg(Math.floor(diff / 3600))
        return Qt.formatDateTime(new Date(ts), "dd MMM hh:mm")
    }

    function updateLabels() {
        let labels = [];
        for (let i = 0; i < positionList.count; i++) {
            let item = positionList.get(i);
            if (item.label && labels.indexOf(item.label) === -1) {
                labels.push(item.label);
            }
        }
        mainWindow.uniqueLabels = labels;
    }

    function selectFinding(index, recenter) {
        if (index < 0 || index >= positionList.count)
            return;
        mainWindow.selectedIndex = index;
        positionListViewer.positionViewAtIndex(index, ListView.Contain);
        if (recenter) {
            let item = positionList.get(index);
            map.centerOn(item.latitude, item.longitude);
        }
    }

    Plugin {
        id: mapPlugin
        name: "osm"
    }

    Filters {
        id: positionFilters
        availableLabels: mainWindow.uniqueLabels
        currentLabel: mainWindow.filter
        currentMinConfidence: mainWindow.minConfidence
        currentFrom: mainWindow.filterFrom
        currentTo: mainWindow.filterTo

        onFiltersApplied: function(label, minConfidence, fromMs, toMs) {
            mainWindow.filter = label
            mainWindow.minConfidence = minConfidence
            mainWindow.filterFrom = fromMs
            mainWindow.filterTo = toMs
            positionFilters.close()
        }
    }

    VideoPopup {
        id: videoPopup
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Tab strip ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: Theme.background

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingLg
                spacing: Theme.spacingXl

                Repeater {
                    model: [qsTr("Live"), qsTr("Timeline")]
                    delegate: Item {
                        id: tabItem
                        required property int index
                        required property string modelData

                        readonly property bool current: mainWindow.currentTab === tabItem.index

                        // Width is measured on the bold text whatever the state:
                        // sizing the layout from tabText.implicitWidth instead
                        // couples it to font.bold, which the click itself flips.
                        // That loop leaves the item — and its MouseArea — with a
                        // stale width, so clicks land outside the hit area.
                        TextMetrics {
                            id: tabMetrics
                            text: tabItem.modelData
                            font.pixelSize: 14
                            font.bold: true
                        }

                        implicitWidth: tabMetrics.width + 2 * Theme.spacingMd
                        Layout.preferredWidth: implicitWidth
                        Layout.fillHeight: true

                        Label {
                            id: tabText
                            anchors.centerIn: parent
                            text: tabItem.modelData
                            font.pixelSize: 14
                            font.bold: tabItem.current
                            color: tabItem.current ? Theme.text : Theme.textMuted
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            radius: 1
                            color: Theme.accent
                            visible: tabItem.current
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mainWindow.currentTab = tabItem.index
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.surface
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: mainWindow.currentTab

            // ── Live view ────────────────────────────────────────────
            Item {
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingMd

                    ColumnLayout {
                        id: sidePanel
            Layout.preferredWidth: mainWindow.width / 3
            Layout.fillHeight: true
            spacing: Theme.spacingLg

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: qsTr("Live Tracker")
                    font.pixelSize: 22
                    font.bold: true
                    color: Theme.text
                }
                Label {
                    text: mainWindow.hasActiveFilter
                        ? qsTr("%1 of %2 tracked").arg(mainWindow.filteredCount).arg(positionList.count)
                        : (positionList.count === 1
                            ? qsTr("1 detection tracked")
                            : qsTr("%1 detections tracked").arg(positionList.count))
                    font.pixelSize: 12
                    color: Theme.textMuted
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                ThemedButton {
                    text: mainWindow.hasActiveFilter ? qsTr("Edit filters") : qsTr("Filter")
                    Layout.fillWidth: !mainWindow.hasActiveFilter
                    bgColor: Theme.accentStrong
                    bgHover: Theme.accent
                    contentColor: Theme.textOnAccent
                    borderColor: "transparent"
                    onClicked: positionFilters.open()
                }

                Rectangle {
                    visible: mainWindow.hasActiveFilter
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
                            text: mainWindow.filterSummary()
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
                            onClicked: mainWindow.clearFilters()
                        }
                    }
                }
            }

            Label {
                text: qsTr("DETECTIONS")
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
                color: Theme.textFaint
                Layout.bottomMargin: -Theme.spacingSm
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: mainWindow.height * 0.25
                Layout.minimumHeight: 100
                radius: Theme.radiusLg
                color: Theme.background
                border.color: Theme.surface
                border.width: 1
                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSm
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ListView {
                        id: positionListViewer
                        model: positionList
                        spacing: Theme.spacingSm
                        delegate: PositionItem {
                            width: positionListViewer.width
                            onRemoved: {
                                positionList.remove(index)
                                mainWindow.selectedIndex = -1
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width - 2 * Theme.spacingLg
                    visible: positionList.count === 0
                    text: qsTr("No detections yet.\nStart the stream to begin tracking.")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.italic: true
                }
            }

            Label {
                text: qsTr("MAP")
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
                color: Theme.textFaint
                Layout.bottomMargin: -Theme.spacingSm
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: mainWindow.height * 0.6
                Layout.minimumHeight: 200
                radius: Theme.radiusLg
                color: Theme.background
                border.color: Theme.surface
                border.width: 1
                clip: true

                MapDisplay {
                    id: map
                    anchors.fill: parent
                    anchors.margins: 1
                }
            }
        }

        CameraViewer {
            id: cameraViewer
            Layout.fillHeight: true
            Layout.preferredWidth: 2 * mainWindow.width / 3
            Layout.fillWidth: true
        }
                }
            }

            // ── Timeline view ────────────────────────────────────────
            TimelineView {}
        }
    }
}
