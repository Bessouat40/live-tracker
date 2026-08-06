#pragma once
#include <string>
#include <vector>

struct GpsPosition {
    double latitude;
    double longitude;
};

class Gps
{

public:
    explicit Gps() = default;
    
    void load(std::string sourcePath);
    GpsPosition getPositions();
};