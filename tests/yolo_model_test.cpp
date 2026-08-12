#include <gtest/gtest.h>

#include <opencv2/opencv.hpp>

#include "detection/yolo_model.h"

TEST(YoloModel, LoadsModelAndProducesValidDetections) {
    ASSERT_NO_THROW({
        YoloModel model("models/yolo26n.onnx", "models/labels.txt");

        cv::Mat image(640, 640, CV_8UC3, cv::Scalar(30, 60, 90));
        const auto detections = model.runInference(image);

        for (const auto &detection : detections) {
            EXPECT_FALSE(detection.label.empty());
            EXPECT_GT(detection.confidence, 0.0f);
            EXPECT_GE(detection.position.x, 0);
            EXPECT_GE(detection.position.y, 0);
            EXPECT_GT(detection.position.w, 0);
            EXPECT_GT(detection.position.h, 0);
        }
    });
}

TEST(YoloModel, AcceptsEmptyDetectionSetWithoutCrashing) {
    YoloModel model("models/yolo26n.onnx", "models/labels.txt");

    cv::Mat image(640, 640, CV_8UC3, cv::Scalar(0, 0, 0));
    EXPECT_NO_THROW(model.runInference(image));
}
