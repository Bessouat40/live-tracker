#include <gtest/gtest.h>

#include "camera_source.h"

TEST(CameraSource, DefaultConstructedIsNotOpened) {
    CameraSource source;
    EXPECT_FALSE(source.isOpened());
}

TEST(CameraSource, LatestFrameIsEmptyWhenNotOpened) {
    CameraSource source;
    EXPECT_TRUE(source.getLatestFrame().empty());
}

TEST(CameraSource, InvalidPathReturnsFalse) {
    CameraSource source;
    EXPECT_FALSE(source.setSource(std::string("does_not_exist.mp4")));
    EXPECT_FALSE(source.isOpened());
}

TEST(CameraSource, InvalidCameraIndexReturnsFalse) {
    CameraSource source;
    EXPECT_FALSE(source.setSource(999));
}