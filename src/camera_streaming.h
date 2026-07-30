#pragma once
#include <QQuickPaintedItem>
#include <QImage>
#include <QString>
#include <QPainter>
#include <QtQml/qqmlregistration.h>
#include <opencv2/opencv.hpp>
#include <thread>
#include <mutex>
#include <atomic>
#include <deque>
#include "yolo_model.h"
#include "image_painter.h"
#include "gps.h"
#include "tracker.h"

class CameraStreaming : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)

public:
    explicit CameraStreaming(QQuickItem *parent = nullptr);
    ~CameraStreaming();
    
    Q_INVOKABLE void setSource(const qint32 &source) { m_source = source; m_sourcePath.clear(); }
    Q_INVOKABLE void setSourcePath(const QString &path) { m_sourcePath = path; }
    Q_INVOKABLE void startStream();
    Q_INVOKABLE void stopStream();

    void paint(QPainter *painter) override;
    bool isRunning() const { return m_running.load(); }
    void captureLoop();
    void inferenceLoop();

signals:
    void positionMocked(double latitude, double longitude, QString label, QString clipPath, double confidence);
    void isRunningChanged();
    void newFrameReady();

private:
    qint32 m_source = 0;
    QString m_sourcePath;
    QImage m_streamedImage;
    YoloModel yoloModel;
    Gps gps;

    std::thread m_captureThread;
    std::thread m_inferenceThread;

    std::mutex m_rawFrameMutex;
    cv::Mat m_latestRawFrame;

    std::mutex m_detectionsMutex;
    std::vector<Detection> m_latestDetections;
    
    mutable std::mutex m_imageMutex;
    std::atomic<bool> m_running = false;
    std::thread m_videoThread;

    Tracker tracker;

    struct ClipRequest { double lat; double lon; std::string label; float confidence; };
    struct ActiveClip  { double lat; double lon; std::string label; float confidence; QString url; };

    std::deque<ClipRequest> m_clipRequests;
    std::mutex m_clipRequestMutex;
    cv::VideoWriter m_clipWriter;
    int m_clipFramesLeft = 0;
    ActiveClip m_currentClip;
    double m_captureFps = 30.0;
    static constexpr double CLIP_SECONDS = 3.0;
    static constexpr std::size_t MAX_PENDING_CLIPS = 30;

    void handleClipRecording(const cv::Mat &annotatedFrame);
    void startClip(const ClipRequest &req, const cv::Size &frameSize);

    std::vector<Detection> detectObjects(cv::Mat &frame);
};