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
    Gps(const std::string& sourcePath);
    
    GpsPosition getPosition();
};