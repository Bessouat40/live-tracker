#include "clip_recorder.h"

#include <stdexcept>

void ClipRecorder::startRecording(
    const std::string& id,
    const std::string& path,
    const cv::Mat& frame,
    double fps)
{
    if (m_videoWriters.find(id) != m_videoWriters.end())
        throw std::invalid_argument("Recording already exists");

    cv::VideoWriter writer(
        path,
        cv::VideoWriter::fourcc('m', 'p', '4', 'v'),
        fps,
        frame.size()
    );

    if (!writer.isOpened())
        throw std::runtime_error("Cannot open video");

    m_videoWriters.emplace(id, std::move(writer));
    addFrameToRecord(id, frame);
}

void ClipRecorder::addFrameToRecord(
    const std::string& id,
    const cv::Mat& frame)
{
    m_videoWriters.at(id).write(frame);
}

void ClipRecorder::stopRecording(const std::string& id)
{
    auto& writer = m_videoWriters.at(id);
    writer.release();

    m_videoWriters.erase(id);
}

bool ClipRecorder::checkRecord(const std::string& id) const
{
    return (m_videoWriters.find(id) != m_videoWriters.end());
}
