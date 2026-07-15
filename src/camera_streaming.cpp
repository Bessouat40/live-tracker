#include "camera_streaming.h"
#include "yolo_model.h"
#include <chrono>

CameraStreaming::CameraStreaming(QQuickItem *parent)
    : QQuickPaintedItem(parent), m_running(false)
{
    connect(this, &CameraStreaming::newFrameReady, this, &QQuickItem::update, Qt::QueuedConnection);
    yoloModel = YoloModel();
    yoloModel.load("models/yolo26n.onnx", "models/labels.txt");
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

void CameraStreaming::detectObjects(cv::Mat &frame) {
    std::vector<std::string> detectedLabels = yoloModel.runInference(frame);
    auto now = std::chrono::steady_clock::now();

    for (const auto& label : detectedLabels) {
        bool shouldTrigger = false;

        if (m_lastDetections.find(label) == m_lastDetections.end()) {
            shouldTrigger = true;
        } else {
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - m_lastDetections[label]).count();
            if (elapsed > MOCK_COOLDOWN_MS) {
                shouldTrigger = true;
            }
        }

        if (shouldTrigger) {
            m_lastDetections[label] = now;

            double mockLat = 44.8377 + ((rand() % 100) / 10000.0) - 0.005;
            double mockLon = -0.5791 + ((rand() % 100) / 10000.0) - 0.005;

            emit positionMocked(mockLat, mockLon, QString::fromStdString(label));
        }
    }
}

void CameraStreaming::readVideo() {
    cv::VideoCapture cap;
    if (!m_sourcePath.isEmpty()) {
        cap.open(m_sourcePath.toStdString());
    } else {
        cap.open(m_source);
    }
    if (!cap.isOpened()) {
        m_running = false;
        return;
    }

    cv::Mat frame;
    while (m_running) {
        cap >> frame;
        if (frame.empty()) {
            CameraStreaming::readVideo();
            return;
        }

        detectObjects(frame);

        QImage qimg((const uchar*)frame.data, frame.cols, frame.rows, 
                    frame.step, QImage::Format_BGR888);
        
        {
            std::lock_guard<std::mutex> lock(m_imageMutex);
            m_streamedImage = qimg.copy();
        }

        emit newFrameReady();

        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
    
    cap.release();
}

void CameraStreaming::startStream() {
    if (m_running) return;
    m_running = true;
    emit isRunningChanged();
    m_videoThread = std::thread(&CameraStreaming::readVideo, this);
}

void CameraStreaming::stopStream() {
    if (m_running) {
        m_running = false;
        if (m_videoThread.joinable()) {
            m_videoThread.join();
        }
        emit isRunningChanged();
    }
}