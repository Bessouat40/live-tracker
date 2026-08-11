pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia

Item {
    id: videoView

    property url selectedVideoUrl: ""
    readonly property double mediaDurationMs: player.duration > 0 ? player.duration : analyzer.durationMs
    readonly property bool hasMedia: player.source.toString() !== ""

    function fmtDuration(ms) {
        let totalSec = Math.max(0, Math.floor(ms / 1000))
        let h = Math.floor(totalSec / 3600)
        let m = Math.floor((totalSec % 3600) / 60)
        let s = totalSec % 60

        function pad2(v) {
            return v < 10 ? "0" + v : "" + v
        }

        if (h > 0)
            return h + ":" + pad2(m) + ":" + pad2(s)
        return m + ":" + pad2(s)
    }

    function clampSeek(ms) {
        let dur = mediaDurationMs
        if (dur <= 0)
            return 0
        return Math.max(0, Math.min(dur, ms))
    }

    VideoTimelineAnalyzer {
        id: analyzer
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Select a video to analyze")
        fileMode: FileDialog.OpenFile
        nameFilters: [
            qsTr("Video files (*.mp4 *.mov *.avi *.mkv *.webm)"),
            qsTr("All files (*)")
        ]
        onAccepted: {
            // A new file invalidates the previous fresco.
            analyzer.clear()
            videoView.selectedVideoUrl = selectedFile
            player.source = selectedFile
            player.pause()
            player.position = 0
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingMd

        Panel {
            Layout.fillWidth: true
            Layout.preferredHeight: 138

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    Label {
                        text: qsTr("VIDEO TIMELINE ANALYSIS")
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                        color: Theme.textFaint
                        Layout.fillWidth: true
                    }

                    ThemedButton {
                        text: qsTr("Upload video")
                        enabled: !analyzer.analyzing
                        onClicked: fileDialog.open()
                    }

                    ThemedButton {
                        text: analyzer.analyzing ? qsTr("Analyzing...") : qsTr("Analyze")
                        enabled: !analyzer.analyzing && videoView.selectedVideoUrl !== ""
                        bgColor: Theme.accentStrong
                        bgHover: Theme.accent
                        contentColor: Theme.textOnAccent
                        borderColor: Theme.accentStrong
                        onClicked: analyzer.analyze(videoView.selectedVideoUrl)
                    }

                    ThemedButton {
                        text: qsTr("Clear")
                        enabled: !analyzer.analyzing && analyzer.eventCount > 0
                        onClicked: analyzer.clear()
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: videoView.selectedVideoUrl !== ""
                        ? qsTr("Selected: %1").arg(videoView.selectedVideoUrl.toString())
                        : qsTr("No video selected")
                    color: videoView.selectedVideoUrl !== "" ? Theme.textMuted : Theme.textFaint
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMd

                    ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: analyzer.progress
                        visible: analyzer.analyzing
                    }

                    // The player knows the duration as soon as the file is
                    // loaded — no need to wait for the analysis to end.
                    Label {
                        text: videoView.mediaDurationMs > 0
                            ? qsTr("Duration: %1").arg(videoView.fmtDuration(videoView.mediaDurationMs))
                            : qsTr("Duration: -")
                        color: Theme.textMuted
                        font.pixelSize: 12
                    }

                    Label {
                        text: qsTr("Events: %1").arg(analyzer.eventCount)
                        color: Theme.textMuted
                        font.pixelSize: 12
                    }
                }

                Label {
                    visible: analyzer.errorString !== ""
                    text: analyzer.errorString
                    color: Theme.danger
                    font.pixelSize: 12
                }
            }
        }

        Panel {
            Layout.fillWidth: true
            Layout.preferredHeight: 320

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                Label {
                    text: qsTr("VIDEO PREVIEW")
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1
                    color: Theme.textFaint
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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
                        text: qsTr("Upload a video to preview and inspect findings.")
                        color: Theme.textFaint
                        font.pixelSize: 12
                    }
                }

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
                        }
                    }

                    Label {
                        text: qsTr("%1 / %2")
                            .arg(videoView.fmtDuration(player.position))
                            .arg(videoView.fmtDuration(videoView.mediaDurationMs))
                        color: Theme.textMuted
                        font.pixelSize: 12
                    }

                    Slider {
                        id: seekSlider
                        Layout.fillWidth: true
                        from: 0
                        to: Math.max(1, videoView.mediaDurationMs)
                        // Follow playback, except while the user is dragging —
                        // a plain `value: player.position` binding would be
                        // destroyed by the first drag and never recover.
                        value: pressed ? value : player.position
                        enabled: videoView.hasMedia

                        onMoved: player.position = videoView.clampSeek(value)
                    }
                }
            }
        }

        Panel {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                Label {
                    text: qsTr("TIMELINE FRESCO (VIDEO TIME)")
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1
                    color: Theme.textFaint
                }

                TimelineFresco {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    events: analyzer.events
                    useRelativeTime: true

                    // Imposed scale = whole video. A 1 s floor keeps the axis
                    // sane during the frame or two before the duration is known.
                    timeMin: 0
                    timeMax: Math.max(1000, videoView.mediaDurationMs)

                    marker: videoView.hasMedia ? player.position : -1

                    emptyText: analyzer.analyzing
                        ? qsTr("Analyzing video frames...")
                        : qsTr("Upload and analyze a video to generate its timeline fresco.")

                    onEventActivated: function (finding) {
                        if (!videoView.hasMedia)
                            return

                        player.position = videoView.clampSeek(finding.ts)
                        player.play()
                    }
                }
            }
        }
    }
}
