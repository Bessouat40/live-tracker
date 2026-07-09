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

class CameraStreaming : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit CameraStreaming(QQuickItem *parent = nullptr);
    ~CameraStreaming();
    
    Q_INVOKABLE void setSource(const QString &source) { m_source = source; }
    Q_INVOKABLE void startStream();
    Q_INVOKABLE void stopStream();

    void paint(QPainter *painter) override;

signals:
    void newFrameReady();

private:
    QString m_source;
    QImage m_streamedImage;
    
    mutable std::mutex m_imageMutex;
    std::atomic<bool> m_running;
    std::thread m_videoThread;

    void readVideo();
};