#include "image_painter.h"

void ImagePainter::drawYoloDetection(cv::Mat &image, const Detection &detection) {
    int left = detection.position.x;
    int top = detection.position.y;
    int w = detection.position.w;
    int h = detection.position.h;
    cv::Rect box(left, top, w, h);
    
    box &= cv::Rect(0, 0, image.cols, image.rows);
    
    cv::rectangle(image, box, cv::Scalar(0, 255, 0), 2);
    cv::putText(image, detection.label, cv::Point(box.x, box.y - 5), 
    cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(0, 255, 0), 2);
}