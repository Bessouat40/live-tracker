#pragma once
#include <opencv2/dnn.hpp>
#include <openvino/openvino.hpp>
#include <string>
#include <vector>
#include "detection.h"

// documentation : https://opencv-opencv.mintlify.app/modules/dnn

class YoloModel
{

public:
    YoloModel(const std::string& modelPath, const std::string& classNamesPath);
    
    std::vector<Detection> runInference(const cv::Mat &image);

private:
    std::vector<Detection> getDetections(const cv::Mat &image);
    std::vector<Detection> getOVDetections(const cv::Mat &image);

    static std::vector<std::string> getClassNames(const std::string &path);
    cv::dnn::Net net;
    ov::Core core;
    ov::CompiledModel compiled_model;
    ov::InferRequest infer_request;
    std::vector<std::string> classNames;
};