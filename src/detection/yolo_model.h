#pragma once
#include <fstream>
#include <iostream>
#include <opencv2/dnn.hpp>
#include <openvino/openvino.hpp>

// documentation : https://opencv-opencv.mintlify.app/modules/dnn

using namespace cv::dnn;

struct DetectionPosition {
    int x;
    int y;
    int w;
    int h;
};

struct Detection {
    int classId;
    std::string label;
    float confidence;
    DetectionPosition position;
};

class YoloModel
{

public:
    explicit YoloModel() = default;
    
    void load(std::string modelPath, std::string classNamesPath);

    std::vector<Detection> runInference(cv::Mat &image);

private:
    std::vector<Detection> getDetections(cv::Mat &image);
    std::vector<Detection> getOVDetections(cv::Mat &image);

    std::vector<std::string> getClassNames(const std::string &path);
    cv::dnn::Net net;
    ov::Core core;
    ov::CompiledModel compiled_model;
    ov::InferRequest infer_request;
    std::vector<std::string> classNames;
};