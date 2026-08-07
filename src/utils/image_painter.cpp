#include "image_painter.h"

void ImagePainter::drawYoloDetection(cv::Mat &image, const Detection &detection) {
    int left = detection.position.x;
    int top = detection.position.y;
    int w = detection.position.w;
    int h = detection.position.h;
    cv::Rect box(left, top, w, h);
    
    box &= cv::Rect(0, 0, image.cols, image.rows);
    
    cv::rectangle(image, box, cv::Scalar(0, 255, 0), 2);

    // Keep the label inside the frame for boxes touching the top edge.
    const int textY = std::max(15, box.y - 5);
    cv::putText(image, detection.label, cv::Point(box.x, textY),
    cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(0, 255, 0), 2);
}