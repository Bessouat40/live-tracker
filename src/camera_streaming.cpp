#include "camera_streaming.h"
#include <chrono>

CameraStreaming::CameraStreaming(QQuickItem *parent)
    : QQuickPaintedItem(parent), m_running(false)
{
    connect(this, &CameraStreaming::newFrameReady, this, &QQuickItem::update, Qt::QueuedConnection);
    yoloModel = YoloModel();
    yoloModel.load("models/yolo26n.onnx", "models/labels.txt");
    gps = Gps();
    gps.load("");
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

std::vector<Detection> CameraStreaming::detectObjects(cv::Mat &frame) {
    std::vector<Detection> detections = yoloModel.runInference(frame);
    auto now = std::chrono::steady_clock::now();

    for (const auto& detection : detections) {
        bool shouldTrigger = false;

        if (m_lastDetections.find(detection.label) == m_lastDetections.end()) {
            shouldTrigger = true;
        } else {
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - m_lastDetections[detection.label]).count();
            if (elapsed > MOCK_COOLDOWN_MS) {
                shouldTrigger = true;
            }
        }

        if (shouldTrigger) {
            m_lastDetections[detection.label] = now;

            GpsPosition pos = gps.getPositions();
            emit positionMocked(pos.latitude, pos.longitude, QString::fromStdString(detection.label));
        }
    }
    return detections;
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

        std::vector<Detection> detections = detectObjects(frame);
        for (const auto& detection : detections) {
            ImagePainter::drawYoloDetection(frame, detection);
        }

        QImage qimg((const uchar*)frame.data, frame.cols, frame.rows, 
                    frame.step, QImage::Format_BGR888);
        
        {
            std::lock_guard<std::mutex> lock(m_imageMutex);
            m_streamedImage = qimg.copy();
        }

        emit newFrameReady();

    }
    
    cap.release();
}

void CameraStreaming::inferenceLoop() {
    cv::Mat frameToProcess;

    while (m_running) {
        int t1 = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
        {
            std::lock_guard<std::mutex> lock(m_rawFrameMutex);
            if (!m_latestRawFrame.empty()) {
                frameToProcess = m_latestRawFrame.clone();
            }
        }

        if (frameToProcess.empty()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
            continue;
        }

        std::vector<Detection> detections = detectObjects(frameToProcess);

        {
            std::lock_guard<std::mutex> lock(m_detectionsMutex);
            m_latestDetections = detections; 
        }
        std::cout << "Inference loop duration: " << (std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count() - t1) << " ms" << std::endl;
    }
}

void CameraStreaming::captureLoop() {
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
        if (frame.empty()) continue;

        {
            std::lock_guard<std::mutex> lock(m_rawFrameMutex);
            m_latestRawFrame = frame.clone(); 
        }

        std::vector<Detection> currentDetections;
        {
            std::lock_guard<std::mutex> lock(m_detectionsMutex);
            currentDetections = m_latestDetections;
        }

        for (const auto& detection : currentDetections) {
            ImagePainter::drawYoloDetection(frame, detection);
        }

        QImage qimg((const uchar*)frame.data, frame.cols, frame.rows, frame.step, QImage::Format_BGR888);
        {
            std::lock_guard<std::mutex> lock(m_imageMutex);
            m_streamedImage = qimg.copy();
        }
        
        emit newFrameReady();
    }
    cap.release();
}

void CameraStreaming::startStream() {
    if (m_running) return;
    m_running = true;
    emit isRunningChanged();

    m_captureThread = std::thread(&CameraStreaming::captureLoop, this);
    m_inferenceThread = std::thread(&CameraStreaming::inferenceLoop, this);
}

void CameraStreaming::stopStream() {
    if (m_running) {
        m_running = false;
        
        if (m_captureThread.joinable()) m_captureThread.join();
        if (m_inferenceThread.joinable()) m_inferenceThread.join();
        
        emit isRunningChanged();
    }
}