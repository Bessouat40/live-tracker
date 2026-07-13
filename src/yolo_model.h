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

    void runInference(cv::Mat &image) {
        cv::Mat blob = cv::dnn::blobFromImage(image, 1.0/255.0, cv::Size(640, 640), 
                                             cv::Scalar(), true, false);

        net.setInput(blob);
        cv::Mat output = net.forward();
        drawBoundingBox(image, output);
    };

private:
    void drawBoundingBox(cv::Mat &image, cv::Mat &output) {
        cv::Mat outputs = output.reshape(1, output.size[1]); 
        cv::transpose(outputs, outputs); 

        int rows = outputs.rows;
        
        for (int i = 0; i < rows; i++) {
            float* data = outputs.ptr<float>(i);
            
            float* classes_scores = data + 4;
            
            cv::Mat scores(1, classNames.size(), CV_32FC1, classes_scores);
            cv::Point classIdPoint;
            double score;
            cv::minMaxLoc(scores, 0, &score, 0, &classIdPoint);
            
            if (score > 0.5) {
                int classId = classIdPoint.x;

                float x = data[0] * (image.cols / 640.0);
                float y = data[1] * (image.rows / 640.0);
                float w = data[2] * (image.cols / 640.0);
                float h = data[3] * (image.rows / 640.0);

                int left = static_cast<int>(x - w / 2);
                int top = static_cast<int>(y - h / 2);

                cv::Rect box(left, top, static_cast<int>(w), static_cast<int>(h));
                
                box &= cv::Rect(0, 0, image.cols, image.rows);

                std::string label = classNames[classId] + ": " + cv::format("%.2f", score);
                cv::rectangle(image, box, cv::Scalar(0, 255, 0), 2);
                cv::putText(image, label, cv::Point(box.x, box.y - 5), 
                            cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(0, 255, 0), 2);
            }
        }
    }
    cv::dnn::Net net;
    std::vector<std::string> classNames;
};