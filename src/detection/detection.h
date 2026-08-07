#pragma once

#include <string>

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