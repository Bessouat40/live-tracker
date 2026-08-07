#include "camera_manager.h"
#include <chrono>
#include <filesystem>
#include <QUrl>

CameraManager::CameraManager(QQuickItem *parent)
    : QQuickPaintedItem(parent),
      m_yoloModel("models/yolo26n.onnx", "models/labels.txt"),
      m_running(false),
      m_gps("")
{
    connect(this, &CameraManager::newFrameReady,
            this, &QQuickItem::update,
            Qt::QueuedConnection);
}

CameraManager::~CameraManager() {
    stopStream();
}

void CameraManager::paint(QPainter *painter) {
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

std::vector<Detection> CameraManager::detectObjects(cv::Mat &frame) {
    std::vector<Detection> detections = m_yoloModel.runInference(frame);
    std::vector<Track> confirmed = m_tracker.update(detections);
    if (!confirmed.empty()) {
        std::lock_guard<std::mutex> lock(m_clipRequestMutex);
        for (const auto& track : confirmed) {
            if (m_clipRequests.size() >= MAX_PENDING_CLIPS)
                break;
            GpsPosition pos = m_gps.getPosition();
            const auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock::now().time_since_epoch()
            ).count();

            std::string id =
                "finding_" +
                std::to_string(timestamp) +
                "_" +
                std::to_string(track.id);
            m_clipRequests.push_back({pos.latitude, pos.longitude, track.label, track.confidence, 0, id});
        }
    }

    return detections;
}

void CameraManager::inferenceLoop() {
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

void CameraManager::captureLoop() {
    while (m_running) {
        cv::Mat frame = m_cameraSource.getLatestFrame();
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

        handleClipRecording(frame);

        QImage qimg((const uchar*)frame.data, frame.cols, frame.rows, frame.step, QImage::Format_BGR888);
        {
            std::lock_guard<std::mutex> lock(m_imageMutex);
            m_streamedImage = qimg.copy();
        }
        
        emit newFrameReady();
    }
}

void CameraManager::startStream() {
    if (m_running) return;
    m_running = true;
    emit isRunningChanged();

    m_captureThread = std::thread(&CameraManager::captureLoop, this);
    m_inferenceThread = std::thread(&CameraManager::inferenceLoop, this);
}

void CameraManager::stopStream() {
    if (m_running) {
        m_running = false;
        
        if (m_captureThread.joinable()) m_captureThread.join();
        if (m_inferenceThread.joinable()) m_inferenceThread.join();

        emit isRunningChanged();
    }
}

void CameraManager::handleClipRecording(const cv::Mat& annotatedFrame)
{
    std::vector<ClipRequest> clipRequests;
    {
        std::lock_guard<std::mutex> lock(m_clipRequestMutex);
        clipRequests = m_clipRequests;
    }

    for (auto it = clipRequests.begin(); it != clipRequests.end(); ) {
        auto& request = *it;

        if (!m_clipRecorder.checkRecord(request.id)) {
            const std::string path =
                "captures/" + request.id + ".mp4";

            m_clipRecorder.startRecording(
                request.id,
                path,
                annotatedFrame,
                m_captureFps
            );

            ++request.framesNumber;
            ++it;
        }
        else if (request.framesNumber <
                 static_cast<int>(m_captureFps * CLIP_SECONDS)) {

            m_clipRecorder.addFrameToRecord(
                request.id,
                annotatedFrame
            );

            ++request.framesNumber;
            ++it;
        }
        else {
            m_clipRecorder.stopRecording(request.id);

            // emit positionMocked(...) ici si nécessaire

            it = m_clipRequests.erase(it);
        }
    }
}