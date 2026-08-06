pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Timeline view: draw a rectangular zone on the map, then read the temporal
// "fresco" of every finding inside that zone that also passes the active
// filters (label / confidence / date range shared with the Live view).
Item {
    id: timelineView

    // ── Data ────────────────────────────────────────────────────────────
    // Findings passing the filters AND inside the drawn zone, sorted by time.
    property var events: computeEvents()
    function computeEvents() {
        // Read every dependency so the binding re-evaluates on change.
        let deps = [mainWindow.filter, mainWindow.minConfidence,
                    mainWindow.filterFrom, mainWindow.filterTo, positionList.count,
                    tlMap.hasZone, tlMap.zMinLat, tlMap.zMaxLat, tlMap.zMinLon, tlMap.zMaxLon]
        let arr = []
        for (let i = 0; i < positionList.count; i++) {
            let it = positionList.get(i)
            if (!mainWindow.matchesFilters(it.label, it.confidence, it.timestamp))
                continue
            if (!tlMap.inZone(it.latitude, it.longitude))
                continue
            arr.push({ index: i, ts: it.timestamp,
                       label: it.label ? it.label : qsTr("Unlabeled"),
                       confidence: it.confidence, latitude: it.latitude,
                       longitude: it.longitude, videoPath: it.videoPath })
        }
        arr.sort(function(a, b) { return a.ts - b.ts })
        return arr
    }

    // Distinct labels present → one swimlane each.
    readonly property var lanes: {
        let s = []
        for (let i = 0; i < events.length; i++) {
            let l = events[i].label
            if (s.indexOf(l) === -1)
                s.push(l)
        }
        s.sort()
        return s
    }

    // Time bounds of the fresco: the filter range if set, else the data span.
    readonly property var bounds: {
        let lo = mainWindow.filterFrom > 0 ? mainWindow.filterFrom
               : (events.length ? events[0].ts : mainWindow.now - 3600000)
        let hi = mainWindow.filterTo > 0 ? mainWindow.filterTo
               : (events.length ? events[events.length - 1].ts : mainWindow.now)
        if (hi - lo < 60000) { // near-zero span → pad to a 1h window
            let mid = (hi + lo) / 2
            lo = mid - 1800000
            hi = mid + 1800000
        }
        return [lo, hi]
    }
    readonly property double tMin: bounds[0]
    readonly property double tMax: bounds[1]
    readonly property double tSpan: Math.max(1, tMax - tMin)

    readonly property var lanePalette: ["#38bdf8", "#fbbf24", "#22c55e", "#f472b6",
                                        "#a78bfa", "#fb923c", "#2dd4bf", "#f87171"]
    function labelColor(label) {
        let i = lanes.indexOf(label)
        if (i < 0)
            i = 0
        return lanePalette[i % lanePalette.length]
    }

    // Short axis-tick formatter: time within a couple of days, else date.
    function fmtTick(ms) {
        if (tSpan <= 2 * 86400000)
            return Qt.formatDateTime(new Date(ms), "HH:mm")
        return Qt.formatDate(new Date(ms), "dd MMM")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingMd

        // ── Toolbar: filters + zone controls ────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            ThemedButton {
                text: mainWindow.hasActiveFilter ? qsTr("Edit filters") : qsTr("Filter")
                bgColor: Theme.accentStrong
                bgHover: Theme.accent
                contentColor: Theme.textOnAccent
                borderColor: "transparent"
                onClicked: positionFilters.open()
            }

            // Active-filter chip
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

            Item { Layout.fillWidth: !mainWindow.hasActiveFilter }

            ThemedButton {
                text: tlMap.drawMode ? qsTr("Drag on map…")
                    : (tlMap.hasZone ? qsTr("Redraw zone") : qsTr("Draw zone"))
                bgColor: tlMap.drawMode ? Theme.active : Theme.surface
                bgHover: Theme.surfaceHover
                contentColor: tlMap.drawMode ? Theme.backgroundDeep : Theme.text
                borderColor: tlMap.drawMode ? Theme.active : Theme.border
                onClicked: tlMap.drawMode = true
            }

            ThemedButton {
                visible: tlMap.hasZone
                text: qsTr("Clear zone")
                bgColor: Theme.dangerSurface
                bgHover: Theme.danger
                contentColor: Theme.danger
                contentHover: Theme.textOnAccent
                borderColor: Theme.danger
                onClicked: tlMap.clearZone()
            }
        }

        // ── Map (draw the zone here) ────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 100 // grows; fresco below has a fixed height
            radius: Theme.radiusLg
            color: Theme.background
            border.color: Theme.surface
            border.width: 1
            clip: true

            MapDisplay {
                id: tlMap
                anchors.fill: parent
                anchors.margins: 1
            }

            // Hint shown while no zone is drawn.
            Rectangle {
                visible: !tlMap.hasZone && !tlMap.drawMode
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingMd
                radius: Theme.radiusPill
                color: Theme.overlay
                border.color: Theme.border
                border.width: 1
                implicitWidth: hintLabel.implicitWidth + 2 * Theme.spacingLg
                implicitHeight: 32

                Label {
                    id: hintLabel
                    anchors.centerIn: parent
                    text: qsTr("Draw a zone to focus the timeline")
                    color: Theme.textMuted
                    font.pixelSize: 12
                }
            }
        }

        // ── Temporal fresco ─────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 240
            radius: Theme.radiusLg
            color: Theme.background
            border.color: Theme.surface
            border.width: 1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: qsTr("TIMELINE")
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                        color: Theme.textFaint
                        Layout.fillWidth: true
                    }
                    Label {
                        text: tlMap.hasZone
                            ? qsTr("%1 in zone").arg(timelineView.events.length)
                            : qsTr("%1 total").arg(timelineView.events.length)
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.textMuted
                    }
                }

                // Plot area
                Item {
                    id: fresco
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property int gutter: 92
                    readonly property real axisH: 22
                    readonly property real plotW: Math.max(1, width - gutter)
                    readonly property real lanesH: Math.max(1, height - axisH)
                    readonly property real laneH: timelineView.lanes.length > 0
                        ? lanesH / timelineView.lanes.length : lanesH

                    function xOf(ts) {
                        let x = gutter + (ts - timelineView.tMin) / timelineView.tSpan * plotW
                        return Math.max(gutter, Math.min(width, x))
                    }
                    function yOf(label) {
                        let i = timelineView.lanes.indexOf(label)
                        if (i < 0)
                            i = 0
                        return i * laneH + laneH / 2
                    }

                    // Lane rows: label + baseline
                    Repeater {
                        model: timelineView.lanes
                        delegate: Item {
                            id: laneRow
                            required property int index
                            required property string modelData
                            x: 0
                            y: index * fresco.laneH
                            width: fresco.width
                            height: fresco.laneH

                            // colour swatch
                            Rectangle {
                                id: swatch
                                x: 0
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8
                                height: 8
                                radius: 4
                                color: timelineView.labelColor(laneRow.modelData)
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                x: swatch.width + Theme.spacingXs
                                width: fresco.gutter - swatch.width - 2 * Theme.spacingXs
                                text: laneRow.modelData
                                color: Theme.textMuted
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            // baseline
                            Rectangle {
                                x: fresco.gutter
                                anchors.verticalCenter: parent.verticalCenter
                                width: fresco.plotW
                                height: 1
                                color: Theme.surface
                            }
                        }
                    }

                    // Time axis ticks
                    Repeater {
                        model: 5
                        delegate: Item {
                            id: tick
                            required property int index
                            readonly property real frac: index / 4
                            readonly property double ts: timelineView.tMin + frac * timelineView.tSpan
                            x: fresco.gutter + frac * fresco.plotW
                            y: 0
                            width: 1
                            height: fresco.height

                            Rectangle {
                                x: 0; y: 0
                                width: 1
                                height: fresco.lanesH
                                color: Theme.surface
                                opacity: 0.5
                            }
                            Label {
                                y: fresco.lanesH + 4
                                x: tick.index === 0 ? 0
                                 : (tick.index === 4 ? -implicitWidth : -implicitWidth / 2)
                                text: timelineView.fmtTick(tick.ts)
                                color: Theme.textFaint
                                font.pixelSize: 9
                            }
                        }
                    }

                    // Detection dots
                    Repeater {
                        model: timelineView.events
                        delegate: Rectangle {
                            id: dot
                            required property var modelData
                            readonly property bool sel: mainWindow.selectedIndex === modelData.index
                            readonly property bool hasClip: modelData.videoPath !== ""

                            width: sel ? 14 : 10
                            height: width
                            radius: width / 2
                            x: fresco.xOf(modelData.ts) - width / 2
                            y: fresco.yOf(modelData.label) - width / 2
                            color: timelineView.labelColor(modelData.label)
                            border.color: sel ? Theme.text : Theme.background
                            border.width: sel ? 2 : 1
                            z: sel ? 10 : 1

                            // Ring marking dots that carry an evidence clip.
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 6
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: Theme.text
                                border.width: 1.5
                                opacity: 0.45
                                visible: dot.hasClip && !dot.sel
                            }

                            MouseArea {
                                id: dotMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mainWindow.selectedIndex = dot.modelData.index
                                    tlMap.centerOn(dot.modelData.latitude, dot.modelData.longitude)
                                    if (dot.hasClip)
                                        videoPopup.openWith(dot.modelData.videoPath, dot.modelData.label)
                                }

                                ToolTip {
                                    id: dotTip
                                    visible: dotMouse.containsMouse
                                    delay: 100
                                    text: "<b>" + dot.modelData.label + "</b><br>"
                                        + Qt.formatDateTime(new Date(dot.modelData.ts), "dd MMM HH:mm:ss")
                                        + (dot.modelData.confidence > 0
                                            ? "<br>Conf: " + Math.round(dot.modelData.confidence * 100) + "%" : "")
                                        + (dot.hasClip ? "<br>▶ " + qsTr("click to play clip")
                                                       : "<br><i>" + qsTr("no clip") + "</i>")
                                    background: Rectangle {
                                        color: Theme.overlay
                                        border.color: Theme.border
                                        border.width: 1
                                        radius: Theme.radiusSm
                                    }
                                    contentItem: Text {
                                        text: dotTip.text
                                        color: Theme.text
                                        font.pixelSize: 11
                                        textFormat: Text.RichText
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    Label {
                        anchors.centerIn: parent
                        width: parent.width - 2 * Theme.spacingLg
                        visible: timelineView.events.length === 0
                        text: tlMap.hasZone
                            ? qsTr("No detections in this zone for the current filters.")
                            : qsTr("No detections match the current filters.")
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Theme.textFaint
                        font.pixelSize: 12
                        font.italic: true
                    }
                }
            }
        }
    }
}
