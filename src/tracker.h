#pragma once
#include <string>
#include <vector>
#include <opencv2/core.hpp>
#include "yolo_model.h"

struct Track {
    int id;
    cv::Rect box;
    std::string label;
    float confidence = 0.0f;
    int hits = 1;
    int timeSinceUpdate = 0;
    bool emitted = false;
};

class Tracker
{
public:
    explicit Tracker(float iouThreshold = 0.3f, int minHits = 3, int maxAge = 15);

    std::vector<Track> update(const std::vector<Detection> &detections);

private:
    static float iou(const cv::Rect &a, const cv::Rect &b);

    std::vector<Track> m_tracks;
    int m_nextId = 0;

    float m_iouThreshold;
    int m_minHits;
    int m_maxAge;
};
