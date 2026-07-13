#pragma once
#include <fstream>
#include <iostream>
#include <opencv2/dnn.hpp>

// documentation : https://opencv-opencv.mintlify.app/modules/dnn

using namespace cv::dnn;


class YoloModel
{

public:
    explicit YoloModel() = default;
    
    void load(std::string modelPath, std::string classNamesPath) {
        net = readNetFromONNX(modelPath);
        net.setPreferableBackend(DNN_BACKEND_OPENCV);
        net.setPreferableTarget(DNN_TARGET_CPU);
        classNames = getClassNames(classNamesPath);
    };

    std::vector<std::string> getClassNames(const std::string &path) {
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

    std::vector<std::string> runInference(cv::Mat &image) {
        std::vector<int> classIds;
        std::vector<float> confidences;
        std::vector<cv::Rect> boxes;

        getDetections(image, classIds, confidences, boxes);
        
        std::vector<int> nmsIndices;
        float scoreThreshold = 0.5f; 
        float nmsThreshold = 0.4f;   
        
        cv::dnn::NMSBoxes(boxes, confidences, scoreThreshold, nmsThreshold, nmsIndices);

        std::set<int> validUniqueClassIds;
        
        for (int idx : nmsIndices) {
            cv::Rect box = boxes[idx];
            int classId = classIds[idx];

            validUniqueClassIds.insert(classId);
            
            float w = static_cast<float>(box.width);
            float h = static_cast<float>(box.height);
            float x = static_cast<float>(box.x) + w / 2.0f;
            float y = static_cast<float>(box.y) + h / 2.0f;
            
            drawBoundingBox(image, classId, x, y, w, h);
        }
        std::vector<std::string> labels;
        for (int id : validUniqueClassIds) {
            labels.push_back(classNames[id]);
        }
        
        return labels;
    }

private:
    void getDetections(cv::Mat &image, std::vector<int>& classIds, std::vector<float>& confidences, std::vector<cv::Rect>& boxes) {
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
                    float x = data[0] * x_factor;
                    float y = data[1] * y_factor;
                    float w = data[2] * x_factor;
                    float h = data[3] * y_factor;
                    
                    int left = static_cast<int>(x - w / 2);
                    int top = static_cast<int>(y - h / 2);
                    
                    classIds.push_back(classIdPoint.x);
                    confidences.push_back(static_cast<float>(maxClassScore));
                    boxes.push_back(cv::Rect(left, top, static_cast<int>(w), static_cast<int>(h)));
                }
            }
        }
    }

    void drawBoundingBox(cv::Mat &image, int classId, float x, float y, float w, float h) {
        int left = static_cast<int>(x - w / 2);
        int top = static_cast<int>(y - h / 2);

        cv::Rect box(left, top, static_cast<int>(w), static_cast<int>(h));
        
        box &= cv::Rect(0, 0, image.cols, image.rows);
        
        // std::string label = classNames[classId] + ": " + cv::format("%.2f", score);
        std::string label = classNames[classId];
        cv::rectangle(image, box, cv::Scalar(0, 255, 0), 2);
        cv::putText(image, label, cv::Point(box.x, box.y - 5), 
                    cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(0, 255, 0), 2);
    }
    cv::dnn::Net net;
    std::vector<std::string> classNames;
};