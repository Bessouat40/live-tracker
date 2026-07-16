#pragma once
#include <fstream>
#include <iostream>
#include <opencv2/opencv.hpp>
#include "yolo_model.h"

namespace ImagePainter
{
    void drawYoloDetection(cv::Mat &image, const Detection &detection);
}