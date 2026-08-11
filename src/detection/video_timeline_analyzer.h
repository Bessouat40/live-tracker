#pragma once

#include <QObject>
#include <QVariantList>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

#include <atomic>
#include <mutex>
#include <thread>

#include "detection/yolo_model.h"

class VideoTimelineAnalyzer : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool analyzing READ analyzing NOTIFY analyzingChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(double durationMs READ durationMs NOTIFY resultsChanged)
    Q_PROPERTY(int eventCount READ eventCount NOTIFY resultsChanged)
    Q_PROPERTY(QVariantList events READ events NOTIFY resultsChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorChanged)

public:
    explicit VideoTimelineAnalyzer(QObject *parent = nullptr);
    ~VideoTimelineAnalyzer() override;

    bool analyzing() const { return m_analyzing.load(); }
    double progress() const { return m_progress.load(); }
    double durationMs() const;
    int eventCount() const;
    QVariantList events() const;
    QString errorString() const;

    Q_INVOKABLE void analyze(const QUrl &videoUrl);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void clear();

signals:
    void analyzingChanged();
    void progressChanged();
    void resultsChanged();
    void errorChanged();

private:
    // ── Calibration ─────────────────────────────────────────────────────
    //
    // Frames analyzed per second of video. Cost is strictly linear: one hour
    // of footage at 2 Hz is ~7200 inferences, a few minutes of processing.
    // Raising this buys temporal precision — short events that fall between
    // two samples are simply invisible — and nothing else, since this
    // analyzer identifies objects by label rather than by tracking them.
    static constexpr double ANALYSIS_HZ = 2.0;

    // A label that disappears for longer than this closes its episode; seeing
    // it again starts a new one. Must be a comfortable multiple of the
    // sampling interval (500 ms at 2 Hz), otherwise a single missed detection
    // splits one continuous presence into several events.
    static constexpr double MERGE_GAP_MS = 3000.0;

    // Episodes seen in fewer sampled frames than this are dropped. A label
    // that shows up once and never again is almost always a false positive.
    static constexpr int MIN_HITS = 2;

    void setError(const QString &error);
    void processVideo(const QString &path);
    static QString toLocalPath(const QUrl &videoUrl);

    YoloModel m_model;
    std::thread m_worker;

    std::atomic<bool> m_analyzing = false;
    std::atomic<bool> m_cancel = false;
    std::atomic<double> m_progress = 0.0;

    mutable std::mutex m_resultMutex;
    QVariantList m_events;
    double m_durationMs = 0.0;
    QString m_error;
};