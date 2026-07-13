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
#include "yolo_model.h"

class CameraStreaming : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit CameraStreaming(QQuickItem *parent = nullptr);
    ~CameraStreaming();
    
    Q_INVOKABLE void setSource(const qint32 &source) { m_source = source; m_sourcePath.clear(); }
    Q_INVOKABLE void setSourcePath(const QString &path) { m_sourcePath = path; }
    Q_INVOKABLE void startStream();
    Q_INVOKABLE void stopStream();

    void paint(QPainter *painter) override;

signals:
    void newFrameReady();

private:
    qint32 m_source = 0;
    QString m_sourcePath;
    QImage m_streamedImage;
    YoloModel yoloModel;
    
    mutable std::mutex m_imageMutex;
    std::atomic<bool> m_running;
    std::thread m_videoThread;

    void readVideo();
    void detectObjects(cv::Mat &frame);
};