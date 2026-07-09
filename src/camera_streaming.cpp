#include "camera_streaming.h"
#include <chrono>

CameraStreaming::CameraStreaming(QQuickItem *parent)
    : QQuickPaintedItem(parent), m_running(false) 
{
    connect(this, &CameraStreaming::newFrameReady, this, &QQuickItem::update, Qt::QueuedConnection);
}

CameraStreaming::~CameraStreaming() {
    stopStream();
}

void CameraStreaming::paint(QPainter *painter) {
    std::lock_guard<std::mutex> lock(m_imageMutex);
    if (m_streamedImage.isNull()) return;

    double widgetRatio = boundingRect().width() / boundingRect().height();
    double imageRatio = (double)m_streamedImage.width() / m_streamedImage.height();
    
    QRectF targetRect;
    if (widgetRatio > imageRatio) {
        double width = boundingRect().height() * imageRatio;
        targetRect = QRectF((boundingRect().width() - width) / 2.0, 0, width, boundingRect().height());
    } else {
        double height = boundingRect().width() / imageRatio;
        targetRect = QRectF(0, (boundingRect().height() - height) / 2.0, boundingRect().width(), height);
    }

    painter->drawImage(targetRect, m_streamedImage, m_streamedImage.rect());
}

void CameraStreaming::readVideo() {
    cv::VideoCapture cap(m_source.toStdString());
    if (!cap.isOpened()) {
        m_running = false;
        return;
    }

    cv::Mat frame;
    while (m_running) {
        cap >> frame;
        if (frame.empty()) break;

        QImage qimg((const uchar*)frame.data, frame.cols, frame.rows, 
                    frame.step, QImage::Format_BGR888);
        
        {
            std::lock_guard<std::mutex> lock(m_imageMutex);
            m_streamedImage = qimg.copy();
        }

        emit newFrameReady();

        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }
    
    cap.release();
}

void CameraStreaming::startStream() {
    if (m_running) return;
    m_running = true;
    m_videoThread = std::thread(&CameraStreaming::readVideo, this);
}

void CameraStreaming::stopStream() {
    if (m_running) {
        m_running = false;
        if (m_videoThread.joinable()) {
            m_videoThread.join();
        }
    }
}