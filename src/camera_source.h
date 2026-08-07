#pragma once

#include <opencv2/opencv.hpp>
#include <string>

class CameraSource
{
public:
    explicit CameraSource();
    explicit CameraSource(int source);
    explicit CameraSource(const std::string& source);

    void setSource(int source);
    void setSource(const std::string& source);

    cv::Mat getLatestFrame();

private:
    cv::VideoCapture m_capture;
};