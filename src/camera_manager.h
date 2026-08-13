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
#include "detection/yolo_model.h"
#include "utils/image_painter.h"
#include "position/gps.h"
#include "detection/tracker.h"
#include "utils/clip_recorder.h"
#include "camera_source.h"

class CameraManager : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)

public:
    explicit CameraManager(QQuickItem *parent = nullptr);
    ~CameraManager();
    
    Q_INVOKABLE void setSource(const qint32 &source);
    Q_INVOKABLE void setSourcePath(const QString &path);
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
    // CPP objects. Declaration order drives construction order, so it must
    // match the constructor's initialiser list.
    YoloModel m_yoloModel;
    Gps m_gps;
    Tracker m_tracker;
    ClipRecorder m_clipRecorder;
    CameraSource m_cameraSource;

    QImage m_streamedImage;
    std::atomic<bool> m_running = false;

    std::thread m_captureThread;
    std::thread m_inferenceThread;

    struct ClipRequest {
        double lat;
        double lon;
        std::string label;
        float confidence;
        int framesNumber;
        std::string id;
        std::string path;
    };

    std::vector<ClipRequest> m_clipRequests;
    std::mutex m_rawFrameMutex;
    std::mutex m_clipRequestMutex;
    cv::Mat m_latestRawFrame;

    std::mutex m_detectionsMutex;
    std::vector<Detection> m_latestDetections;

    mutable std::mutex m_imageMutex;

    double m_captureFps = 30.0;
    static constexpr double CLIP_SECONDS = 3.0;
    static constexpr std::size_t MAX_PENDING_CLIPS = 30;

    std::vector<Detection> detectObjects(cv::Mat &frame);
    void handleClipRecording(const cv::Mat &annotatedFrame);
};