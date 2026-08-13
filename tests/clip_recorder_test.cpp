#include <gtest/gtest.h>

#include <filesystem>
#include <string>

#include <opencv2/opencv.hpp>

#include "utils/clip_recorder.h"

namespace {

cv::Mat makeFrame(int width, int height, cv::Scalar color) {
    cv::Mat frame(height, width, CV_8UC3, color);
    return frame;
}

std::filesystem::path makeTempVideoPath(const std::string& name) {
    return std::filesystem::temp_directory_path() / name;
}

} // namespace

TEST(ClipRecorder, StartsAndStopsCleanly) {
    ClipRecorder recorder;
    auto path = makeTempVideoPath("clip_recorder_start_stop.mp4");
    std::filesystem::remove(path);

    cv::Mat frame = makeFrame(64, 48, cv::Scalar(10, 20, 30));

    EXPECT_TRUE(recorder.startRecording("cam-1", path.string(), frame, 10.0));
    EXPECT_TRUE(recorder.checkRecord("cam-1"));

    cv::Mat nextFrame = makeFrame(64, 48, cv::Scalar(40, 50, 60));
    recorder.addFrameToRecord("cam-1", nextFrame);
    recorder.stopRecording("cam-1");

    EXPECT_FALSE(recorder.checkRecord("cam-1"));
    EXPECT_TRUE(std::filesystem::exists(path));
    EXPECT_GT(std::filesystem::file_size(path), 0ULL);

    std::filesystem::remove(path);
}

TEST(ClipRecorder, IgnoresEmptyOrMismatchedFrames) {
    ClipRecorder recorder;
    auto path = makeTempVideoPath("clip_recorder_ignored_frames.mp4");
    std::filesystem::remove(path);

    cv::Mat validFrame = makeFrame(32, 24, cv::Scalar(1, 2, 3));
    EXPECT_TRUE(recorder.startRecording("cam-2", path.string(), validFrame, 12.0));

    recorder.addFrameToRecord("cam-2", cv::Mat());
    recorder.addFrameToRecord("cam-2", makeFrame(16, 12, cv::Scalar(4, 5, 6)));

    EXPECT_TRUE(recorder.checkRecord("cam-2"));
    recorder.stopRecording("cam-2");
    std::filesystem::remove(path);
}

TEST(ClipRecorder, RejectsInvalidRecordingParameters) {
    ClipRecorder recorder;
    auto path = makeTempVideoPath("clip_recorder_invalid.mp4");
    std::filesystem::remove(path);

    cv::Mat frame = makeFrame(20, 20, cv::Scalar(255, 0, 0));

    EXPECT_FALSE(recorder.startRecording("cam-3", path.string(), cv::Mat(), 10.0));
    EXPECT_FALSE(recorder.startRecording("cam-3", path.string(), frame, 0.0));
    EXPECT_FALSE(recorder.checkRecord("cam-3"));

    std::filesystem::remove(path);
}
