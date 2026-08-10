#pragma once

#include <opencv2/opencv.hpp>
#include <string>
#include <unordered_map>

class ClipRecorder {
    public:
        bool startRecording(
            const std::string& id,
            const std::string& path,
            const cv::Mat& frame,
            double fps
        );
        void addFrameToRecord(const std::string& id, const cv::Mat& frame);
        void stopRecording(const std::string& id);
        bool checkRecord(const std::string& id) const;

    private:
        struct Record {
            cv::VideoWriter writer;
            // writers reject frames of any other size
            cv::Size frameSize;
        };

        std::unordered_map<std::string, Record> m_records;
};
