#include <gtest/gtest.h>

#include <opencv2/opencv.hpp>

#include "detection/detection.h"
#include "utils/image_painter.h"

namespace {

bool isGreen(const cv::Mat &image, int x, int y) {
    return image.at<cv::Vec3b>(y, x) == cv::Vec3b(0, 255, 0);
}

// Empty label -> no text is drawn, so every green pixel belongs to the box outline.
Detection boxAt(int x, int y, int w, int h) {
    return Detection{0, "", 0.9f, DetectionPosition{x, y, w, h}};
}

} // namespace

// The box {20,20,40,40} has corners (20,20) and (60,60); check each edge midpoint.
TEST(ImagePainter, DrawsOutlineAtRequestedLocation) {
    cv::Mat image = cv::Mat::zeros(100, 100, CV_8UC3);

    ImagePainter::drawYoloDetection(image, boxAt(20, 20, 40, 40));

    EXPECT_TRUE(isGreen(image, 40, 20)) << "top edge";
    EXPECT_TRUE(isGreen(image, 40, 60)) << "bottom edge";
    EXPECT_TRUE(isGreen(image, 20, 40)) << "left edge";
    EXPECT_TRUE(isGreen(image, 60, 40)) << "right edge";
}

TEST(ImagePainter, OnlyOutlineIsDrawn) {
    cv::Mat image = cv::Mat::zeros(100, 100, CV_8UC3);

    ImagePainter::drawYoloDetection(image, boxAt(20, 20, 40, 40));

    EXPECT_FALSE(isGreen(image, 40, 40)) << "inside the box stays black";
    EXPECT_FALSE(isGreen(image, 90, 90)) << "outside the box stays black";
}

// A box overflowing the frame must be clipped instead of writing out of bounds.
TEST(ImagePainter, ClipsBoxToImageBounds) {
    cv::Mat image = cv::Mat::zeros(100, 100, CV_8UC3);

    ASSERT_NO_THROW(ImagePainter::drawYoloDetection(image, boxAt(80, 80, 40, 40)));

    EXPECT_TRUE(isGreen(image, 80, 90)) << "visible part of the clipped outline";
}

