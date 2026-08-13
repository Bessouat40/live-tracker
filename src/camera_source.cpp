#include "camera_source.h"

#include <iostream>

CameraSource::CameraSource() = default;

CameraSource::CameraSource(int source)
{
    setSource(source);
}

CameraSource::CameraSource(const std::string& source)
{
    setSource(source);
}

cv::Mat CameraSource::getLatestFrame()
{
    if (!m_capture.isOpened())
        return {};

    cv::Mat frame;
    m_capture >> frame;
    return frame;
}

bool CameraSource::setSource(int source)
{
    if (m_capture.isOpened())
        m_capture.release();
    if (!m_capture.open(source)) {
        std::cerr << "CameraSource: cannot open camera index " << source << std::endl;
        return false;
    }
    return true;
}

bool CameraSource::setSource(const std::string& source)
{
    if (m_capture.isOpened())
        m_capture.release();
    if (!m_capture.open(source)) {
        std::cerr << "CameraSource: cannot open video source " << source << std::endl;
        return false;
    }
    return true;
}
