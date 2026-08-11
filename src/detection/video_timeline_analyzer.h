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
    Q_INVOKABLE void clear();

signals:
    void analyzingChanged();
    void progressChanged();
    void resultsChanged();
    void errorChanged();

private:
    // Frames analyzed per second of video. This is also the tracker's
    // association budget: between two analyzed frames an object moves, and
    // past a certain gap the IoU match fails and a fresh id (i.e. a duplicate
    // event) is born. There is no real-time constraint on a file, so this can
    // be raised well above the live pipeline's rate — cost is CPU time only.
    static constexpr double ANALYSIS_HZ = 15.0;

    // A track id reappearing after this much silence is treated as a new
    // object rather than a continuation, in case the tracker recycles ids.
    static constexpr double MERGE_GAP_MS = 1500.0;

    void setError(const QString &error);
    void processVideo(const QString &path);
    static QString toLocalPath(const QUrl &videoUrl);

    YoloModel m_model;
    std::thread m_worker;

    std::atomic<bool> m_analyzing = false;
    std::atomic<double> m_progress = 0.0;

    mutable std::mutex m_resultMutex;
    QVariantList m_events;
    double m_durationMs = 0.0;
    QString m_error;
};