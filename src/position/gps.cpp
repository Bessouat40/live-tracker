#include "gps.h"

Gps::Gps(const std::string& sourcePath) {
    // Load GPS data from the specified source path
}

GpsPosition Gps::getPosition() {
    double mockLat = 44.8377 + ((rand() % 100) / 10000.0) - 0.005;
    double mockLon = -0.5791 + ((rand() % 100) / 10000.0) - 0.005;
    return {mockLat, mockLon};
}