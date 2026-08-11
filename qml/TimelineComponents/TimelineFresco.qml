pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

/*
    The temporal fresco: one swimlane per label, one dot per finding.
    Purely presentational — it is handed the events to draw, decides how to
    draw them, and reports clicks. It never picks which findings to show.
*/
Item {
    id: fresco

    property var events: []
    property string emptyText: ""

    signal eventActivated(var finding)

    // ── Lanes and colours ───────────────────────────────────────────────
    readonly property var lanes: {
        let s = []
        for (let i = 0; i < events.length; i++) {
            if (s.indexOf(events[i].label) === -1)
                s.push(events[i].label)
        }
        s.sort()
        return s
    }

    readonly property var lanePalette: ["#38bdf8", "#fbbf24", "#22c55e", "#f472b6",
                                    "#a78bfa", "#fb923c", "#2dd4bf", "#f87171"]

    // Resolved once per lane set, rather than a linear scan per dot.
    readonly property var laneColors: {
        let m = ({})
        for (let i = 0; i < lanes.length; i++)
            m[lanes[i]] = lanePalette[i % lanePalette.length]
        return m
    }
    function colorOf(label) {
        return laneColors[label] !== undefined ? laneColors[label] : lanePalette[0]
    }

    // ── Time scale ──────────────────────────────────────────────────────
    // The filter range if one is set, else the span of the data.
    readonly property var bounds: {
        let lo = FilterState.fromMs > 0 ? FilterState.fromMs
               : (events.length ? events[0].ts : Clock.now - 3600000)
        let hi = FilterState.toMs > 0 ? FilterState.toMs
               : (events.length ? events[events.length - 1].ts : Clock.now)
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

    // Short axis-tick formatter: time within a couple of days, else date.
    function fmtTick(ms) {
        if (tSpan <= 2 * 86400000)
            return Qt.formatDateTime(new Date(ms), "HH:mm")
        return Qt.formatDate(new Date(ms), "dd MMM")
    }

    // ── Geometry ────────────────────────────────────────────────────────
    readonly property int gutter: 92
    readonly property real axisH: 22
    readonly property real plotW: Math.max(1, width - gutter)
    readonly property real lanesH: Math.max(1, height - axisH)
    readonly property real laneH: lanes.length > 0 ? lanesH / lanes.length : lanesH

    function xOf(ts) {
        let x = gutter + (ts - tMin) / tSpan * plotW
        return Math.max(gutter, Math.min(width, x))
    }
    function yOf(label) {
        let i = lanes.indexOf(label)
        if (i < 0)
            i = 0
        return i * laneH + laneH / 2
    }

    // Lane rows: swatch, label, baseline
    Repeater {
        model: fresco.lanes
        delegate: Item {
            id: laneRow
            required property int index
            required property string modelData

            x: 0
            y: index * fresco.laneH
            width: fresco.width
            height: fresco.laneH

            Rectangle {
                id: swatch
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: fresco.colorOf(laneRow.modelData)
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
            readonly property double ts: fresco.tMin + frac * fresco.tSpan

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
                text: fresco.fmtTick(tick.ts)
                color: Theme.textFaint
                font.pixelSize: 9
            }
        }
    }

    // Detection dots
    Repeater {
        model: fresco.events
        delegate: FrescoDot {
            id: dot
            required property var modelData

            finding: modelData
            laneColor: fresco.colorOf(modelData.label)
            x: fresco.xOf(modelData.ts) - width / 2
            y: fresco.yOf(modelData.label) - height / 2

            onActivated: fresco.eventActivated(dot.modelData)
        }
    }

    Label {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.spacingLg
        visible: fresco.events.length === 0
        text: fresco.emptyText
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: Theme.textFaint
        font.pixelSize: 12
        font.italic: true
    }
}
