#pragma once

#include <opencv2/opencv.hpp>
#include <string>

class CameraSource
{
public:
    explicit CameraSource();
    explicit CameraSource(int source);
    explicit CameraSource(const std::string& source);

    bool setSource(int source);
    bool setSource(const std::string& source);

    bool isOpened() const { return m_capture.isOpened(); }

    cv::Mat getLatestFrame();

private:
    cv::VideoCapture m_capture;
};