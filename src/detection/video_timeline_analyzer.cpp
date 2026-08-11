#include "video_timeline_analyzer.h"
#include "tracker.h"

#include <QMetaObject>

#include <opencv2/opencv.hpp>

#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <vector>

VideoTimelineAnalyzer::VideoTimelineAnalyzer(QObject *parent)
    : QObject(parent),
      m_model("models/yolo26n.onnx", "models/labels.txt")
{
}

VideoTimelineAnalyzer::~VideoTimelineAnalyzer()
{
    if (m_worker.joinable())
        m_worker.join();
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

    m_progress.store(0.0);
    emit progressChanged();
    emit errorChanged();
    emit resultsChanged();
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

    m_progress.store(0.0);
    emit progressChanged();

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

    // The tracker associates detections between two *analyzed* frames, so the
    // sampling rate is also its association budget: the wider the gap, the
    // further an object moves and the more likely the match fails (and a new
    // id — i.e. a duplicate event — is born). ANALYSIS_HZ is the knob.
    const int sampleStep = std::max(1, static_cast<int>(std::lround(fps / ANALYSIS_HZ)));

    // Fresh tracker per video: ids must not leak from a previous analysis.
    Tracker tracker;

    // One entry per track id, not per detection.
    struct TrackAggregate {
        double firstMs = 0.0;
        double lastMs = 0.0;
        std::string label;
        float bestConfidence = 0.0f;
        int hits = 0;
    };
    std::unordered_map<int, TrackAggregate> aggregates;
    std::vector<int> firstSeenOrder; // ids in order of appearance

    cv::Mat frame;
    int frameIndex = 0;
    double lastMs = 0.0;

    while (cap.read(frame)) {
        if (frame.empty()) {
            ++frameIndex;
            continue;
        }

        if ((frameIndex % sampleStep) != 0) {
            ++frameIndex;
            continue;
        }

        std::vector<Detection> detections = m_model.runInference(frame);
        std::vector<Track> tracks = tracker.update(detections);

        double tsMs = cap.get(cv::CAP_PROP_POS_MSEC);
        if (tsMs <= 0.0)
            tsMs = (static_cast<double>(frameIndex) / fps) * 1000.0;
        lastMs = std::max(lastMs, tsMs);

        for (const auto &track : tracks) {
            auto [it, inserted] = aggregates.try_emplace(track.id);
            TrackAggregate &agg = it->second;

            if (inserted) {
                agg.firstMs = tsMs;
                agg.label = track.label;
                firstSeenOrder.push_back(track.id);
            }
            agg.lastMs = tsMs;
            agg.bestConfidence = std::max(agg.bestConfidence, track.confidence);
            ++agg.hits;
        }

        if (frameCount > 0.0) {
            const double p = std::clamp(static_cast<double>(frameIndex) / frameCount, 0.0, 1.0);
            m_progress.store(p);
            QMetaObject::invokeMethod(this, [this]() { emit progressChanged(); }, Qt::QueuedConnection);
        }

        ++frameIndex;
    }

    // firstSeenOrder is already chronological — the video is walked forwards.
    QVariantList localEvents;
    localEvents.reserve(static_cast<int>(firstSeenOrder.size()));

    int serial = 0;
    for (const int id : firstSeenOrder) {
        const TrackAggregate &agg = aggregates.at(id);

        QVariantMap event;
        event.insert(QStringLiteral("index"), serial++);
        event.insert(QStringLiteral("trackId"), id);
        event.insert(QStringLiteral("ts"), agg.firstMs);            // fresco anchor
        event.insert(QStringLiteral("tsEnd"), agg.lastMs);
        event.insert(QStringLiteral("durationMs"), agg.lastMs - agg.firstMs);
        event.insert(QStringLiteral("hits"), agg.hits);
        event.insert(QStringLiteral("label"), QString::fromStdString(agg.label));
        event.insert(QStringLiteral("confidence"), static_cast<double>(agg.bestConfidence));
        event.insert(QStringLiteral("latitude"), 0.0);
        event.insert(QStringLiteral("longitude"), 0.0);
        event.insert(QStringLiteral("videoPath"), QString());
        localEvents.push_back(event);
    }

    const double computedDuration = std::max(duration, lastMs);

    {
        std::lock_guard<std::mutex> lock(m_resultMutex);
        m_events = localEvents;
        m_durationMs = std::max(1.0, computedDuration);
    }

    m_progress.store(1.0);
}
