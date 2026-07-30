#include "camera_streaming.h"
#include <chrono>
#include <filesystem>
#include <QUrl>

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
    std::vector<Track> confirmed = tracker.update(detections);
    if (!confirmed.empty()) {
        std::lock_guard<std::mutex> lock(m_clipRequestMutex);
        for (const auto& track : confirmed) {
            if (m_clipRequests.size() >= MAX_PENDING_CLIPS)
                break;
            GpsPosition pos = gps.getPositions();
            m_clipRequests.push_back({pos.latitude, pos.longitude, track.label});
        }
    }

    return detections;
}

void CameraStreaming::startClip(const ClipRequest &req, const cv::Size &frameSize) {
    namespace fs = std::filesystem;
    std::error_code ec;
    fs::create_directories("captures", ec);

    const auto ts = std::chrono::duration_cast<std::chrono::milliseconds>(
                        std::chrono::system_clock::now().time_since_epoch()).count();
    const std::string path = "captures/finding_" + std::to_string(ts) + ".mp4";

    const double fps = (m_captureFps >= 1.0) ? m_captureFps : 30.0;

    m_clipWriter.open(path, cv::VideoWriter::fourcc('a', 'v', 'c', '1'), fps, frameSize, true);
    if (!m_clipWriter.isOpened())
        m_clipWriter.open(path, cv::VideoWriter::fourcc('m', 'p', '4', 'v'), fps, frameSize, true);

    if (!m_clipWriter.isOpened()) {
        std::cerr << "CameraStreaming: could not open VideoWriter for " << path << std::endl;
        emit positionMocked(req.lat, req.lon, QString::fromStdString(req.label), QString());
        return;
    }

    m_clipFramesLeft = static_cast<int>(fps * CLIP_SECONDS);
    m_currentClip.lat = req.lat;
    m_currentClip.lon = req.lon;
    m_currentClip.label = req.label;

    const std::string absPath = fs::absolute(path, ec).string();
    m_currentClip.url = QUrl::fromLocalFile(QString::fromStdString(absPath)).toString();
}

void CameraStreaming::handleClipRecording(const cv::Mat &annotatedFrame) {
    if (m_clipFramesLeft == 0) {
        ClipRequest req;
        bool hasRequest = false;
        {
            std::lock_guard<std::mutex> lock(m_clipRequestMutex);
            if (!m_clipRequests.empty()) {
                req = m_clipRequests.front();
                m_clipRequests.pop_front();
                hasRequest = true;
            }
        }
        if (hasRequest)
            startClip(req, annotatedFrame.size());
    }

    if (m_clipFramesLeft > 0 && m_clipWriter.isOpened()) {
        m_clipWriter.write(annotatedFrame);
        if (--m_clipFramesLeft == 0) {
            m_clipWriter.release();
            emit positionMocked(m_currentClip.lat, m_currentClip.lon,
                                QString::fromStdString(m_currentClip.label),
                                m_currentClip.url);
        }
    }
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

    m_captureFps = cap.get(cv::CAP_PROP_FPS);
    if (m_captureFps < 1.0 || m_captureFps > 120.0)
        m_captureFps = 30.0;

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

        handleClipRecording(frame);

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

        if (m_clipWriter.isOpened()) m_clipWriter.release();
        m_clipFramesLeft = 0;

        emit isRunningChanged();
    }
}