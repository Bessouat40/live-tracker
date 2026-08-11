pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia

Item {
    id: videoView

    focus: true

    property url selectedVideoUrl: ""
    readonly property double durationMs: player.duration > 0 ? player.duration : analyzer.durationMs
    readonly property bool hasMedia: player.source.toString() !== ""

    // ── Filters ─────────────────────────────────────────────────────────
    FilterCriteria { id: filters }

    readonly property var availableLabels: filters.labelsIn(analyzer.events)
    readonly property var shownEvents: filters.select(analyzer.events, "ts")

    // ── Selection ───────────────────────────────────────────────────────
    // Stored by event index, not by position, so it survives a filter change.
    property int selectedIndex: -1

    readonly property int selectedPos: {
        for (let i = 0; i < shownEvents.length; i++) {
            if (shownEvents[i].index === selectedIndex)
                return i
        }
        return -1
    }
    readonly property var selected: selectedPos >= 0 ? shownEvents[selectedPos] : null

    function selectAt(pos) {
        if (shownEvents.length === 0)
            return
        let e = shownEvents[Math.max(0, Math.min(shownEvents.length - 1, pos))]
        selectedIndex = e.index
        if (hasMedia)
            player.position = clampSeek(e.ts)
    }

    function step(delta) {
        if (shownEvents.length === 0)
            return
        selectAt(selectedPos < 0 ? (delta > 0 ? 0 : shownEvents.length - 1)
                                 : selectedPos + delta)
    }

    Keys.onPressed: function (event) {
        switch (event.key) {
        case Qt.Key_Left:   videoView.step(-1); break
        case Qt.Key_Right:  videoView.step(1); break
        case Qt.Key_Home:   videoView.selectAt(0); break
        case Qt.Key_End:    videoView.selectAt(videoView.shownEvents.length - 1); break
        case Qt.Key_Escape: videoView.selectedIndex = -1; break
        case Qt.Key_Space:
            if (videoView.hasMedia)
                player.playbackState === MediaPlayer.PlayingState ? player.pause()
                                                                  : player.play()
            break
        default: return
        }
        event.accepted = true
    }

    function fmt(ms) {
        let t = Math.max(0, Math.floor(ms / 1000))
        let m = Math.floor(t / 60)
        let s = t % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    function clampSeek(ms) {
        return durationMs <= 0 ? 0 : Math.max(0, Math.min(durationMs, ms))
    }

    VideoTimelineAnalyzer { id: analyzer }

    FileDialog {
        id: fileDialog
        title: qsTr("Select a video to analyze")
        nameFilters: [qsTr("Video files (*.mp4 *.mov *.avi *.mkv *.webm)"),
                      qsTr("All files (*)")]
        onAccepted: {
            analyzer.clear()
            filters.clear()
            videoView.selectedIndex = -1
            videoView.selectedVideoUrl = selectedFile
            player.pause()
            videoView.forceActiveFocus()
        }
    }

    Filters {
        id: filtersPopup
        parent: videoView
        showTimeRange: false
        availableLabels: videoView.availableLabels
        currentLabel: filters.label
        currentMinConfidence: filters.minConfidence

        onFiltersApplied: function (label, minConfidence) {
            filters.apply(label, minConfidence, 0, 0)
            close()
            videoView.forceActiveFocus()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        // ── Toolbar ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            ThemedButton {
                text: qsTr("Upload")
                enabled: !analyzer.analyzing
                onClicked: fileDialog.open()
            }

            ThemedButton {
                text: analyzer.analyzing ? qsTr("Analyzing…") : qsTr("Analyze")
                enabled: !analyzer.analyzing && videoView.selectedVideoUrl !== ""
                bgColor: Theme.accentStrong
                bgHover: Theme.accent
                contentColor: Theme.textOnAccent
                borderColor: Theme.accentStrong
                onClicked: {
                    videoView.selectedIndex = -1
                    analyzer.analyze(videoView.selectedVideoUrl)
                }
            }

            ThemedButton {
                text: analyzer.analyzing ? qsTr("Cancel") : qsTr("Clear")
                enabled: analyzer.analyzing || analyzer.eventCount > 0
                onClicked: {
                    if (analyzer.analyzing) {
                        analyzer.cancel()
                    } else {
                        analyzer.clear()
                        filters.clear()
                        videoView.selectedIndex = -1
                    }
                }
            }

            ThemedButton {
                text: filters.active ? qsTr("Filters ●") : qsTr("Filters")
                enabled: analyzer.eventCount > 0
                onClicked: filtersPopup.open()
            }

            ProgressBar {
                Layout.preferredWidth: 120
                from: 0; to: 1
                value: analyzer.progress
                visible: analyzer.analyzing
            }

            Item { Layout.fillWidth: true }

            Label {
                text: analyzer.eventCount === 0 ? ""
                    : (videoView.shownEvents.length === analyzer.eventCount
                       ? qsTr("%1 events").arg(analyzer.eventCount)
                       : qsTr("%1 / %2 events").arg(videoView.shownEvents.length)
                                               .arg(analyzer.eventCount))
                color: Theme.textMuted
                font.pixelSize: 12
            }
        }

        Label {
            Layout.fillWidth: true
            visible: analyzer.errorString !== ""
            text: analyzer.errorString
            color: Theme.danger
            font.pixelSize: 12
        }

        // ── Video (takes all the room left over) ────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 200
            radius: Theme.radiusMd
            color: "#0B1220"
            border.color: Theme.border
            border.width: 1
            clip: true

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }

            MediaPlayer {
                id: player
                videoOutput: videoOutput
                source: videoView.selectedVideoUrl
            }

            Label {
                anchors.centerIn: parent
                visible: !videoView.hasMedia
                text: qsTr("Upload a video to preview and analyze it.")
                color: Theme.textFaint
                font.pixelSize: 12
            }
        }

        // ── Transport ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            ThemedButton {
                text: player.playbackState === MediaPlayer.PlayingState
                    ? qsTr("Pause") : qsTr("Play")
                enabled: videoView.hasMedia
                onClicked: {
                    if (player.playbackState === MediaPlayer.PlayingState)
                        player.pause()
                    else
                        player.play()
                    videoView.forceActiveFocus()
                }
            }

            Label {
                text: videoView.fmt(player.position) + " / " + videoView.fmt(videoView.durationMs)
                color: Theme.textMuted
                font.pixelSize: 12
            }

            Slider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, videoView.durationMs)
                // Follow playback except while dragging: a plain
                // `value: player.position` binding dies on the first drag.
                value: pressed ? value : player.position
                enabled: videoView.hasMedia
                onMoved: player.position = videoView.clampSeek(value)
            }
        }

        // ── Selected episode: fixed height, always present ───────────────
        // Reserving the space unconditionally is what keeps the video from
        // resizing every time the selection changes.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingSm
                spacing: Theme.spacingMd

                Image {
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 48
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    source: videoView.selected && videoView.selected.thumbnail
                        ? videoView.selected.thumbnail : ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        text: videoView.selected ? videoView.selected.label
                                                 : qsTr("No episode selected")
                        color: videoView.selected ? Theme.text : Theme.textFaint
                        font.pixelSize: 13
                        font.bold: videoView.selected !== null
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: videoView.selected
                            ? qsTr("%1 → %2 · %3% · %4 frames")
                                .arg(videoView.fmt(videoView.selected.ts))
                                .arg(videoView.fmt(videoView.selected.tsEnd))
                                .arg(Math.round(videoView.selected.confidence * 100))
                                .arg(videoView.selected.hits)
                            : qsTr("Click a dot below, or use ← → to browse")
                        color: Theme.textMuted
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Label {
                    visible: videoView.selectedPos >= 0
                    text: (videoView.selectedPos + 1) + " / " + videoView.shownEvents.length
                    color: Theme.textMuted
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }

        // ── Fresco ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            TimelineFresco {
                anchors.fill: parent
                anchors.margins: Theme.spacingSm

                events: videoView.shownEvents
                useRelativeTime: true
                timeMin: 0
                timeMax: Math.max(1000, videoView.durationMs)
                marker: videoView.hasMedia ? player.position : -1
                selectedIndex: videoView.selectedIndex

                emptyText: analyzer.analyzing ? qsTr("Analyzing video frames…")
                    : (analyzer.eventCount > 0
                       ? qsTr("No detections match the current filters.")
                       : qsTr("Analyze the video to build its timeline."))

                onSelectionRequested: function (index) {
                    videoView.selectedIndex = index
                    videoView.forceActiveFocus()
                }

                onEventActivated: function (finding) {
                    videoView.selectedIndex = finding.index
                    if (videoView.hasMedia)
                        player.position = videoView.clampSeek(finding.ts)
                    videoView.forceActiveFocus()
                }
            }
        }
    }
}
