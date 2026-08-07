#include "camera_manager.h"
#include <chrono>
#include <filesystem>
#include <QUrl>

CameraManager::CameraManager(QQuickItem *parent)
    : QQuickPaintedItem(parent),
      m_yoloModel("models/yolo26n.onnx", "models/labels.txt"),
      m_gps(""),
      m_running(false)
{
    std::error_code ec;
    std::filesystem::create_directories("captures", ec);
    if (ec)
        std::cerr << "CameraManager: cannot create captures/: " << ec.message() << std::endl;

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
    }
}

void CameraManager::captureLoop() {
    while (m_running) {
        cv::Mat frame = m_cameraSource.getLatestFrame();
        if (frame.empty()) {
            // No source, or the video file ended: back off instead of
            // spinning a core at 100%.
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            continue;
        }
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
    if (annotatedFrame.empty())
        return;

    const int totalFrames = std::max(1, static_cast<int>(m_captureFps * CLIP_SECONDS));

    // Clips whose recording ended on this frame. Collected under the lock and
    // emitted outside of it, so a slot can never re-enter us while we hold it.
    std::vector<ClipRequest> finished;

    {
        std::lock_guard<std::mutex> lock(m_clipRequestMutex);

        // Iterate m_clipRequests directly: mutating a copy would drop every
        // framesNumber increment and its iterators are not valid here anyway.
        for (auto it = m_clipRequests.begin(); it != m_clipRequests.end(); ) {
            ClipRequest &request = *it;

            if (!m_clipRecorder.checkRecord(request.id)) {
                const std::string path = "captures/" + request.id + ".mp4";

                if (!m_clipRecorder.startRecording(request.id, path, annotatedFrame, m_captureFps)) {
                    // No writer: still report the finding, just without a clip.
                    request.path.clear();
                    finished.push_back(request);
                    it = m_clipRequests.erase(it);
                    continue;
                }

                request.path = path;
                request.framesNumber = 1;
                ++it;
            }
            else if (request.framesNumber < totalFrames) {
                m_clipRecorder.addFrameToRecord(request.id, annotatedFrame);
                ++request.framesNumber;
                ++it;
            }
            else {
                m_clipRecorder.stopRecording(request.id);
                finished.push_back(request);
                it = m_clipRequests.erase(it);
            }
        }
    }

    for (const auto &clip : finished) {
        QString url;
        if (!clip.path.empty()) {
            std::error_code ec;
            const std::string absPath = std::filesystem::absolute(clip.path, ec).string();
            if (!ec)
                url = QUrl::fromLocalFile(QString::fromStdString(absPath)).toString();
        }

        emit positionMocked(clip.lat, clip.lon,
                            QString::fromStdString(clip.label),
                            url, clip.confidence);
    }
}