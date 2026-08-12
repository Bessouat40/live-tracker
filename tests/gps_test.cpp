#include <gtest/gtest.h>

#include "position/gps.h"

TEST(GPS, GetPositionStaysWithinBounds) {
    Gps gps;
    for (int i = 0; i < 100; ++i) {
        GpsPosition position = gps.getPosition();
        EXPECT_GE(position.latitude, -90.0);
        EXPECT_LE(position.latitude, 90.0);
        EXPECT_GE(position.longitude, -180.0);
        EXPECT_LE(position.longitude, 180.0);
    }
}

