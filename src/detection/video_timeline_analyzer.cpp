#include "video_timeline_analyzer.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QMetaObject>
#include <QStandardPaths>

#include <opencv2/opencv.hpp>

#include <algorithm>
#include <cmath>
#include <string>
#include <unordered_map>
#include <vector>

VideoTimelineAnalyzer::VideoTimelineAnalyzer(QObject *parent)
    : QObject(parent),
      m_model("models/yolo26n.onnx", "models/labels.txt")
{
}

VideoTimelineAnalyzer::~VideoTimelineAnalyzer()
{
    // Without this the destructor would block until a full analysis finishes,
    // freezing application shutdown for minutes on a long video.
    m_cancel.store(true);
    if (m_worker.joinable())
        m_worker.join();

    purgeThumbnails();
}

double VideoTimelineAnalyzer::durationMs() const
{
    std::lock_guard<std::mutex> lock(m_resultMutex);
    return m_durationMs;
}

int VideoTimelineAnalyzer::eventCount() const
{
    std::lock_guard<std::mutex> lock(m_resultMutex);
    return static_cast<int>(m_events.size());
}

QVariantList VideoTimelineAnalyzer::events() const
{
    std::lock_guard<std::mutex> lock(m_resultMutex);
    return m_events;
}

QString VideoTimelineAnalyzer::errorString() const
{
    std::lock_guard<std::mutex> lock(m_resultMutex);
    return m_error;
}

QString VideoTimelineAnalyzer::toLocalPath(const QUrl &videoUrl)
{
    if (videoUrl.isLocalFile())
        return videoUrl.toLocalFile();

    const QString asString = videoUrl.toString();
    if (asString.startsWith("file://"))
        return QUrl(asString).toLocalFile();

    return asString;
}

void VideoTimelineAnalyzer::setError(const QString &error)
{
    {
        std::lock_guard<std::mutex> lock(m_resultMutex);
        m_error = error;
    }
    emit errorChanged();
}

// Thumbnails live in the app's cache directory rather than next to the
// binary: they are disposable, and writing them relative to the working
// directory would break as soon as the app is launched from elsewhere.
void VideoTimelineAnalyzer::purgeThumbnails()
{
    if (m_thumbnailDir.isEmpty())
        return;

    QDir(m_thumbnailDir).removeRecursively();
    m_thumbnailDir.clear();
}

void VideoTimelineAnalyzer::clear()
{
    if (m_analyzing.load())
        return;

    {
        std::lock_guard<std::mutex> lock(m_resultMutex);
        m_events.clear();
        m_durationMs = 0.0;
        m_error.clear();
    }

    purgeThumbnails();

    m_progress.store(0.0);
    emit progressChanged();
    emit errorChanged();
    emit resultsChanged();
}

void VideoTimelineAnalyzer::cancel()
{
    if (!m_analyzing.load())
        return;

    // The worker checks this flag once per frame and stops at the next one,
    // publishing whatever it has found so far.
    m_cancel.store(true);
}

void VideoTimelineAnalyzer::analyze(const QUrl &videoUrl)
{
    if (m_analyzing.load())
        return;

    if (m_worker.joinable())
        m_worker.join();

    const QString path = toLocalPath(videoUrl);
    if (path.isEmpty()) {
        setError(QStringLiteral("No video selected."));
        return;
    }

    {
        std::lock_guard<std::mutex> lock(m_resultMutex);
        m_events.clear();
        m_durationMs = 0.0;
        m_error.clear();
    }
    emit errorChanged();
    emit resultsChanged();

    // A timestamped directory per run: the QML Image cache keys on the file
    // URL, so reusing names across runs would show the previous thumbnails.
    purgeThumbnails();
    const QString cacheRoot = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    m_thumbnailDir = QDir(cacheRoot).filePath(
        QStringLiteral("thumbs/%1-%2")
            .arg(QFileInfo(path).completeBaseName())
            .arg(QDateTime::currentMSecsSinceEpoch()));
    QDir().mkpath(m_thumbnailDir);

    m_progress.store(0.0);
    emit progressChanged();

    m_cancel.store(false);
    m_analyzing.store(true);
    emit analyzingChanged();

    m_worker = std::thread([this, path]() {
        processVideo(path);

        QMetaObject::invokeMethod(this, [this]() {
            m_analyzing.store(false);
            emit analyzingChanged();
            emit progressChanged();
            emit resultsChanged();
        }, Qt::QueuedConnection);
    });
}

void VideoTimelineAnalyzer::processVideo(const QString &path)
{
    cv::VideoCapture cap(path.toStdString());
    if (!cap.isOpened()) {
        QMetaObject::invokeMethod(this, [this]() {
            setError(QStringLiteral("Unable to open selected video."));
        }, Qt::QueuedConnection);
        return;
    }

    const double fpsRaw = cap.get(cv::CAP_PROP_FPS);
    const double fps = fpsRaw > 0.0 ? fpsRaw : 30.0;
    const double frameCount = cap.get(cv::CAP_PROP_FRAME_COUNT);
    const double duration = (frameCount > 0.0) ? (frameCount / fps) * 1000.0 : 0.0;
    const int sampleStep = std::max(1, static_cast<int>(std::lround(fps / ANALYSIS_HZ)));

    // An "episode": a continuous stretch during which a given label keeps
    // being detected. There is no object identity here — two distinct cars
    // merge into a single "car" episode. What this buys is a readable fresco:
    // a parked car yields one event instead of one per sampled frame.
    struct Episode {
        double firstMs = 0.0;
        double lastMs = 0.0;
        std::string label;
        float bestConfidence = 0.0f;
        int hits = 0;          // sampled frames this label appeared in
        int maxConcurrent = 0; // most simultaneous detections in one frame
        cv::Mat thumbnail;     // already downscaled; written to disk at the end
    };

    std::vector<Episode> episodes;
    // label -> index, in `episodes`, of the episode currently open for it.
    std::unordered_map<std::string, std::size_t> openEpisode;

    struct FrameEntry {
        int count = 0;
        float bestConfidence = 0.0f;
    };
    std::unordered_map<std::string, FrameEntry> perFrame;

    // Downscaled once per new episode. Kept in memory rather than written
    // immediately, so that episodes later dropped by MIN_HITS never touch
    // the disk. A few hundred KB per episode at most.
    cv::Mat scaled;

    cv::Mat frame;
    int frameIndex = 0;
    double lastMs = 0.0;

    while (!m_cancel.load()) {
        // grab() advances the stream without decoding into a cv::Mat, so the
        // frames that are never analyzed cost almost nothing — at 2 Hz on
        // 30 fps footage that is 29 frames out of 30.
        if ((frameIndex % sampleStep) != 0) {
            if (!cap.grab())
                break;
            ++frameIndex;
            continue;
        }

        if (!cap.read(frame))
            break;
        if (frame.empty()) {
            ++frameIndex;
            continue;
        }

        double tsMs = cap.get(cv::CAP_PROP_POS_MSEC);
        if (tsMs <= 0.0)
            tsMs = (static_cast<double>(frameIndex) / fps) * 1000.0;
        lastMs = std::max(lastMs, tsMs);

        const std::vector<Detection> detections = m_model.runInference(frame);

        // Collapse the frame by label first: three cars in one frame are one
        // hit on the "car" lane, not three.
        perFrame.clear();
        for (const auto &det : detections) {
            FrameEntry &entry = perFrame[det.label];
            ++entry.count;
            entry.bestConfidence = std::max(entry.bestConfidence, det.confidence);
        }

        for (const auto &[label, entry] : perFrame) {
            auto openIt = openEpisode.find(label);

            const bool continues =
                openIt != openEpisode.end() &&
                (tsMs - episodes[openIt->second].lastMs) <= MERGE_GAP_MS;

            if (continues) {
                Episode &ep = episodes[openIt->second];
                ep.lastMs = tsMs;
                ep.bestConfidence = std::max(ep.bestConfidence, entry.bestConfidence);
                ep.maxConcurrent = std::max(ep.maxConcurrent, entry.count);
                ++ep.hits;
            } else {
                Episode ep;
                ep.firstMs = tsMs;
                ep.lastMs = tsMs;
                ep.label = label;
                ep.bestConfidence = entry.bestConfidence;
                ep.maxConcurrent = entry.count;
                ep.hits = 1;

                const double scale = static_cast<double>(THUMBNAIL_WIDTH)
                                   / std::max(1, frame.cols);
                if (scale < 1.0)
                    cv::resize(frame, scaled, cv::Size(), scale, scale, cv::INTER_AREA);
                else
                    scaled = frame;
                ep.thumbnail = scaled.clone();

                episodes.push_back(ep);
                // Overwrites any stale entry: exceeding the gap is precisely
                // what closed the previous episode for this label.
                openEpisode[label] = episodes.size() - 1;
            }
        }

        if (frameCount > 0.0) {
            const double p = std::clamp(static_cast<double>(frameIndex) / frameCount, 0.0, 1.0);
            m_progress.store(p);
            QMetaObject::invokeMethod(this, [this]() { emit progressChanged(); }, Qt::QueuedConnection);
        }

        ++frameIndex;
    }

    // Episodes are appended in order of first appearance, hence already
    // chronological — sorted explicitly so the fresco can rely on it.
    std::sort(episodes.begin(), episodes.end(), [](const Episode &a, const Episode &b) {
        return a.firstMs < b.firstMs;
    });

    const std::vector<int> jpegParams = { cv::IMWRITE_JPEG_QUALITY, 80 };
    const QDir thumbDir(m_thumbnailDir);

    QVariantList localEvents;
    localEvents.reserve(static_cast<int>(episodes.size()));

    int serial = 0;
    for (const Episode &ep : episodes) {
        if (ep.hits < MIN_HITS)
            continue;

        QString thumbnailUrl;
        if (!ep.thumbnail.empty() && !m_thumbnailDir.isEmpty()) {
            const QString file = thumbDir.absoluteFilePath(
                QStringLiteral("ep_%1.jpg").arg(serial, 4, 10, QLatin1Char('0')));
            if (cv::imwrite(file.toStdString(), ep.thumbnail, jpegParams))
                thumbnailUrl = QUrl::fromLocalFile(file).toString();
        }

        QVariantMap event;
        event.insert(QStringLiteral("index"), serial++);
        event.insert(QStringLiteral("ts"), ep.firstMs);   // fresco anchor
        event.insert(QStringLiteral("tsEnd"), ep.lastMs);
        event.insert(QStringLiteral("durationMs"), ep.lastMs - ep.firstMs);
        event.insert(QStringLiteral("hits"), ep.hits);
        event.insert(QStringLiteral("count"), ep.maxConcurrent);
        event.insert(QStringLiteral("label"), QString::fromStdString(ep.label));
        event.insert(QStringLiteral("confidence"), static_cast<double>(ep.bestConfidence));
        event.insert(QStringLiteral("thumbnail"), thumbnailUrl);
        event.insert(QStringLiteral("latitude"), 0.0);
        event.insert(QStringLiteral("longitude"), 0.0);
        event.insert(QStringLiteral("videoPath"), QString());
        localEvents.push_back(event);
    }

    const double computedDuration = std::max(duration, lastMs);

    // Partial results are published on cancellation too: a fresco covering
    // the first half of the video beats an empty one.
    {
        std::lock_guard<std::mutex> lock(m_resultMutex);
        m_events = localEvents;
        m_durationMs = std::max(1.0, computedDuration);
    }

    m_progress.store(1.0);
}
