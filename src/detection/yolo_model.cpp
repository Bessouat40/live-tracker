#include "yolo_model.h"
#include <opencv2/dnn.hpp>
#include <opencv2/opencv.hpp>
#include <algorithm>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <unordered_map>

using namespace cv::dnn;

YoloModel::YoloModel(
    const std::string& modelPath,
    const std::string& classNamesPath)
    : net(cv::dnn::readNetFromONNX(modelPath)),
      compiled_model(core.compile_model(modelPath, "AUTO")),
      infer_request(compiled_model.create_infer_request()),
      classNames(getClassNames(classNamesPath))
{
    net.setPreferableBackend(cv::dnn::DNN_BACKEND_OPENCV);
    net.setPreferableTarget(cv::dnn::DNN_TARGET_CPU);

    if (classNames.empty())
        throw std::runtime_error("YoloModel: no class names loaded from " + classNamesPath);
}

std::vector<std::string> YoloModel::getClassNames(const std::string &path) {
    std::vector<std::string> classNames;
    std::ifstream infile(path);

    if (infile) {
        std::string line;
        while (getline(infile, line)) {
            // Remove carriage return if present (for Windows compatibility)
            if (!line.empty() && line.back() == '\r')
                line.pop_back();
            classNames.emplace_back(line);
        }
    } else {
        std::cerr << "ERROR: Failed to access class name path: " << path << std::endl;
    }

    return classNames;
}

std::vector<Detection> YoloModel::runInference(const cv::Mat &image) {
    std::vector<Detection> rawDetections = getOVDetections(image);
    // std::vector<Detection> rawDetections = getDetections(image);

    const float scoreThreshold = 0.5f;
    const float nmsThreshold = 0.4f;

    // NMS must run per class. Run globally, a high-confidence "person" would
    // suppress an overlapping "bicycle" even though they are distinct objects.
    std::unordered_map<int, std::vector<std::size_t>> indicesByClass;
    for (std::size_t i = 0; i < rawDetections.size(); ++i)
        indicesByClass[rawDetections[i].classId].push_back(i);

    std::vector<Detection> finalDetections;
    finalDetections.reserve(rawDetections.size());

    for (const auto &[classId, indices] : indicesByClass) {
        std::vector<cv::Rect> boxes;
        std::vector<float> confidences;
        boxes.reserve(indices.size());
        confidences.reserve(indices.size());

        for (std::size_t idx : indices) {
            const auto &det = rawDetections[idx];
            boxes.emplace_back(det.position.x, det.position.y, det.position.w, det.position.h);
            confidences.push_back(det.confidence);
        }

        std::vector<int> kept;
        cv::dnn::NMSBoxes(boxes, confidences, scoreThreshold, nmsThreshold, kept);

        for (int k : kept)
            finalDetections.push_back(rawDetections[indices[k]]);
    }

    return finalDetections;
}

std::vector<Detection> YoloModel::getOVDetections(const cv::Mat &image) {
    std::vector<Detection> detections;
    
    cv::Mat blob = cv::dnn::blobFromImage(image, 1.0/255.0, cv::Size(640, 640), 
                                          cv::Scalar(), true, false);

    auto input_port = compiled_model.input();
    
    ov::Tensor input_tensor(input_port.get_element_type(), input_port.get_shape(), blob.ptr<float>());
    infer_request.set_input_tensor(input_tensor);
    
    infer_request.infer(); 
    
    auto output = infer_request.get_output_tensor(0);
    auto shape = output.get_shape();
    float* output_data = output.data<float>();

    float x_factor = image.cols / 640.0f;
    float y_factor = image.rows / 640.0f;

    cv::Mat predictions(shape[1], shape[2], CV_32FC1, output_data); 
    
    cv::transpose(predictions, predictions);

    for(int i = 0; i < predictions.rows; i++) {
        const float* data = predictions.ptr<float>(i);

        const int numClasses = predictions.cols - 4;
        const float* classScores = data + 4;

        auto bestScoreIterator = std::max_element(
            classScores,
            classScores + numClasses
        );

        const float maxClassScore = *bestScoreIterator;

        const int classId = static_cast<int>(
            std::distance(classScores, bestScoreIterator)
        );
        
        if(maxClassScore > 0.5) {
            if (classId < 0 || static_cast<std::size_t>(classId) >= classNames.size())
                continue;

            float x = data[0] * x_factor;
            float y = data[1] * y_factor;
            float w = data[2] * x_factor;
            float h = data[3] * y_factor;

            int left = static_cast<int>(x - w / 2);
            int top = static_cast<int>(y - h / 2);

            Detection detection;
            detection.classId = classId;
            detection.label = classNames[classId];
            detection.confidence = static_cast<float>(maxClassScore);
            detection.position = {left, top, static_cast<int>(w), static_cast<int>(h)};
            
            detections.push_back(detection);
        }
    }
    
    return detections;
}

std::vector<Detection> YoloModel::getDetections(const cv::Mat &image) {
    std::vector<Detection> detections;
    cv::Mat blob = cv::dnn::blobFromImage(image, 1.0/255.0, cv::Size(640, 640), 
                                    cv::Scalar(), true, false);

    net.setInput(blob);
    std::vector<cv::Mat> outputs;
    net.forward(outputs);

    float x_factor = image.cols / 640.0f;
    float y_factor = image.rows / 640.0f;
    
    for(cv::Mat& output : outputs) {
        cv::Mat predictions;
        if (output.dims == 3) {
            predictions = output.reshape(1, output.size[1]); 
            cv::transpose(predictions, predictions); 
        } else {
            predictions = output;
        }
        
        for(int i = 0; i < predictions.rows; i++) {
            float* data = predictions.ptr<float>(i);
            
            int numClasses = predictions.cols - 4; 
            cv::Mat scores(1, numClasses, CV_32FC1, data + 4);
            
            double maxClassScore;
            cv::Point classIdPoint;
            cv::minMaxLoc(scores, 0, &maxClassScore, 0, &classIdPoint);
            
            if(maxClassScore > 0.5) {
                if (classIdPoint.x < 0 ||
                    static_cast<std::size_t>(classIdPoint.x) >= classNames.size())
                    continue;

                float x = data[0] * x_factor;
                float y = data[1] * y_factor;
                float w = data[2] * x_factor;
                float h = data[3] * y_factor;

                int left = static_cast<int>(x - w / 2);
                int top = static_cast<int>(y - h / 2);

                Detection detection;
                detection.classId = classIdPoint.x;
                detection.label = classNames[classIdPoint.x];
                detection.confidence = static_cast<float>(maxClassScore);
                DetectionPosition position = {left, top, static_cast<int>(w), static_cast<int>(h)};
                detection.position = position;
                detections.push_back(detection);
            }
        }
    }
    return detections;
}
