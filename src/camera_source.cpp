#include "camera_source.h"

CameraSource::CameraSource()
{
    m_capture.open(0);

    if (!m_capture.isOpened())
        throw std::runtime_error("Cannot open camera source");
}

CameraSource::CameraSource(int source)
{
    m_capture.open(source);

    if (!m_capture.isOpened())
        throw std::runtime_error("Cannot open camera source");
}

CameraSource::CameraSource(const std::string& source)
{
    m_capture.open(source);

    if (!m_capture.isOpened())
        throw std::runtime_error("Cannot open video source");
}

cv::Mat CameraSource::getLatestFrame()
{
    cv::Mat frame;
    m_capture >> frame;
    return frame;
}

void CameraSource::setSource(int source)
{
    m_capture.open(source);
}

void CameraSource::setSource(const std::string& source)
{
    m_capture.open(source);
}