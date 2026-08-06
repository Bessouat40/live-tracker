#include "gps.h"

void Gps::load(std::string sourcePath) {
    // Load GPS data from the specified source path
}

GpsPosition Gps::getPositions() {
    double mockLat = 44.8377 + ((rand() % 100) / 10000.0) - 0.005;
    double mockLon = -0.5791 + ((rand() % 100) / 10000.0) - 0.005;
    return {mockLat, mockLon};
}