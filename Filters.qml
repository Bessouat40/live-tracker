pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: positionFilters
    modal: true
    focus: true

    width: Math.min(420, parent.width * 0.9)
    height: Math.min(680, contentLayout.implicitHeight + topPadding + bottomPadding)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: Theme.radiusLg
    }

    padding: Theme.spacingXxl

    // Current filter state, injected by the parent.
    property var availableLabels: []
    property string currentLabel: ""
    property real currentMinConfidence: 0
    property double currentFrom: 0 // epoch ms, 0 = unbounded
    property double currentTo: 0   // epoch ms, 0 = unbounded

    // Working copies edited inside the popup, committed on Apply.
    property string wLabel: ""
    property real wConfidence: 0

    signal filtersApplied(string label, real minConfidence, double fromMs, double toMs)

    // ── Date/time helpers ───────────────────────────────────
    function fmtDate(ms) {
        return ms > 0 ? Qt.formatDate(new Date(ms), "yyyy-MM-dd") : ""
    }
    function fmtTime(ms) {
        return ms > 0 ? Qt.formatTime(new Date(ms), "HH:mm") : ""
    }
    // Builds an epoch ms from masked date/time fields. Returns 0 when the
    // date is missing/incomplete (unbounded). isEnd fills the day's tail.
    function parseDT(dateStr, timeStr, isEnd) {
        if (dateStr.indexOf(" ") !== -1 || dateStr.length < 10)
            return 0
        let dp = dateStr.split("-")
        let y = parseInt(dp[0], 10)
        let mo = parseInt(dp[1], 10)
        let d = parseInt(dp[2], 10)

        let h = isEnd ? 23 : 0
        let mi = isEnd ? 59 : 0
        if (timeStr.indexOf(" ") === -1 && timeStr.length >= 5) {
            let tp = timeStr.split(":")
            h = parseInt(tp[0], 10)
            mi = parseInt(tp[1], 10)
        }

        let dt = new Date(y, mo - 1, d, h, mi, isEnd ? 59 : 0, isEnd ? 999 : 0)
        let t = dt.getTime()
        return isNaN(t) ? 0 : t
    }

    onOpened: {
        wLabel = currentLabel
        wConfidence = currentMinConfidence
        fromDate.text = fmtDate(currentFrom)
        fromTime.text = fmtTime(currentFrom)
        toDate.text = fmtDate(currentTo)
        toTime.text = fmtTime(currentTo)
    }

    // ── Reusable masked inputs ──────────────────────────────
    component DateField: TextField {
        id: dctrl
        inputMask: "0000-00-00"
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        color: Theme.text
        font.pixelSize: 13
        selectByMouse: true
        background: Rectangle {
            radius: Theme.radiusMd
            color: Theme.background
            border.color: dctrl.activeFocus ? Theme.accent : Theme.border
            border.width: 1
        }
    }

    component TimeField: TextField {
        id: tctrl
        inputMask: "00:00"
        Layout.preferredWidth: 74
        Layout.preferredHeight: 36
        color: Theme.text
        font.pixelSize: 13
        horizontalAlignment: TextInput.AlignHCenter
        selectByMouse: true
        background: Rectangle {
            radius: Theme.radiusMd
            color: Theme.background
            border.color: tctrl.activeFocus ? Theme.accent : Theme.border
            border.width: 1
        }
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: Theme.spacingXl

        // ── Header ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Label {
                text: qsTr("Filters")
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

        // ── Label ───────────────────────────────────────────
        Label {
            text: qsTr("LABEL")
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
            color: Theme.textFaint
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 150
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: Theme.spacingSm

                ButtonGroup {
                    id: radioGroup
                }

                RadioButton {
                    id: anyLabel
                    text: qsTr("Any label")
                    checked: positionFilters.wLabel === ""
                    ButtonGroup.group: radioGroup
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    hoverEnabled: true
                    onClicked: positionFilters.wLabel = ""

                    indicator: Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        x: anyLabel.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 10
                        color: Theme.background
                        border.color: anyLabel.checked ? Theme.accent
                                    : (anyLabel.hovered ? Theme.textDisabled : Theme.border)
                        border.width: anyLabel.checked ? 6 : 1
                    }

                    contentItem: Text {
                        text: anyLabel.text
                        font.pixelSize: anyLabel.font.pixelSize
                        font.italic: true
                        color: anyLabel.checked ? Theme.accent : Theme.textMuted
                        leftPadding: anyLabel.indicator.width + anyLabel.spacing
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Repeater {
                    model: positionFilters.availableLabels

                    delegate: RadioButton {
                        id: rBtn
                        required property string modelData
                        text: modelData
                        checked: positionFilters.wLabel === modelData
                        ButtonGroup.group: radioGroup
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        hoverEnabled: true
                        onClicked: positionFilters.wLabel = modelData

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
            }
        }

        // ── Minimum confidence ──────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Label {
                text: qsTr("MINIMUM CONFIDENCE")
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
                color: Theme.textFaint
                Layout.fillWidth: true
            }

            Label {
                text: positionFilters.wConfidence > 0
                    ? "≥ " + Math.round(positionFilters.wConfidence * 100) + "%"
                    : qsTr("any")
                font.pixelSize: 12
                font.bold: true
                color: positionFilters.wConfidence > 0 ? Theme.accent : Theme.textMuted
            }
        }

        Slider {
            id: confSlider
            Layout.fillWidth: true
            from: 0
            to: 1
            stepSize: 0.05
            value: positionFilters.wConfidence
            onMoved: positionFilters.wConfidence = value

            background: Rectangle {
                x: confSlider.leftPadding
                y: confSlider.topPadding + confSlider.availableHeight / 2 - height / 2
                width: confSlider.availableWidth
                height: 4
                radius: 2
                color: Theme.background

                Rectangle {
                    width: confSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                }
            }

            handle: Rectangle {
                x: confSlider.leftPadding + confSlider.visualPosition * (confSlider.availableWidth - width)
                y: confSlider.topPadding + confSlider.availableHeight / 2 - height / 2
                implicitWidth: 18
                implicitHeight: 18
                radius: 9
                color: confSlider.pressed ? Theme.accentStrong : Theme.text
                border.color: Theme.accent
                border.width: 2
            }
        }

        // ── Time range (absolute) ───────────────────────────
        Label {
            text: qsTr("TIME RANGE")
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
            color: Theme.textFaint
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Theme.spacingSm
            rowSpacing: Theme.spacingSm

            Label {
                text: qsTr("From")
                font.pixelSize: 13
                color: Theme.textMuted
                Layout.preferredWidth: 40
            }
            DateField { id: fromDate }
            TimeField { id: fromTime }

            Label {
                text: qsTr("To")
                font.pixelSize: 13
                color: Theme.textMuted
                Layout.preferredWidth: 40
            }
            DateField { id: toDate }
            TimeField { id: toTime }
        }

        Label {
            text: qsTr("Date YYYY-MM-DD · time HH:MM · leave empty for no limit")
            font.pixelSize: 10
            font.italic: true
            color: Theme.textFaint
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // ── Actions ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd

            ThemedButton {
                text: qsTr("Clear")
                Layout.fillWidth: true
                bgColor: Theme.dangerSurface
                bgHover: Theme.danger
                contentColor: Theme.danger
                contentHover: Theme.textOnAccent
                borderColor: Theme.danger

                onClicked: {
                    positionFilters.wLabel = ""
                    positionFilters.wConfidence = 0
                    fromDate.text = ""
                    fromTime.text = ""
                    toDate.text = ""
                    toTime.text = ""
                    positionFilters.filtersApplied("", 0, 0, 0)
                }
            }

            ThemedButton {
                text: qsTr("Apply")
                Layout.fillWidth: true
                bgColor: Theme.accentStrong
                bgHover: Theme.accent
                contentColor: Theme.textOnAccent
                borderColor: "transparent"

                onClicked: positionFilters.filtersApplied(
                    positionFilters.wLabel,
                    positionFilters.wConfidence,
                    positionFilters.parseDT(fromDate.text, fromTime.text, false),
                    positionFilters.parseDT(toDate.text, toTime.text, true))
            }
        }
    }
}
