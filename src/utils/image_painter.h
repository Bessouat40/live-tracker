#pragma once
#include <algorithm>
#include <opencv2/opencv.hpp>
#include "../detection/detection.h"

namespace ImagePainter
{
    void drawYoloDetection(cv::Mat &image, const Detection &detection);
}