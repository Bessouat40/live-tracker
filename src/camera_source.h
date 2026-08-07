#pragma once

#include <opencv2/opencv.hpp>
#include <string>

class CameraSource
{
public:
    // The default source opens nothing: it is a member of a QML element, and
    // throwing from there would abort the whole scene construction.
    explicit CameraSource();
    explicit CameraSource(int source);
    explicit CameraSource(const std::string& source);

    // Return false instead of throwing when the source cannot be opened.
    bool setSource(int source);
    bool setSource(const std::string& source);

    bool isOpened() const { return m_capture.isOpened(); }

    // Returns an empty Mat when no source is open or the stream ended.
    cv::Mat getLatestFrame();

private:
    cv::VideoCapture m_capture;
};