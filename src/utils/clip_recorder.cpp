#include "clip_recorder.h"

#include <iostream>

bool ClipRecorder::startRecording(
    const std::string& id,
    const std::string& path,
    const cv::Mat& frame,
    double fps)
{
    if (m_records.find(id) != m_records.end())
        return false;

    if (frame.empty() || fps <= 0.0) {
        std::cerr << "ClipRecorder: refusing to record " << id
                  << " (empty frame or fps <= 0)" << std::endl;
        return false;
    }

    Record record;
    record.frameSize = frame.size();
    record.writer.open(
        path,
        cv::VideoWriter::fourcc('a', 'v', 'c', '1'),
        fps,
        record.frameSize
    );

    if (!record.writer.isOpened()) {
        record.writer.open(
            path,
            cv::VideoWriter::fourcc('m', 'p', '4', 'v'),
            fps,
            record.frameSize
        );
    }

    if (!record.writer.isOpened()) {
        std::cerr << "ClipRecorder: cannot open writer for " << path << std::endl;
        return false;
    }

    auto [it, inserted] = m_records.emplace(id, std::move(record));
    it->second.writer.write(frame);
    return true;
}

void ClipRecorder::addFrameToRecord(
    const std::string& id,
    const cv::Mat& frame)
{
    auto it = m_records.find(id);
    if (it == m_records.end())
        return;

    // A writer opened for one resolution silently produces a corrupt clip if
    // fed anything else, so drop mismatched frames instead.
    if (frame.empty() || frame.size() != it->second.frameSize)
        return;

    it->second.writer.write(frame);
}

void ClipRecorder::stopRecording(const std::string& id)
{
    auto it = m_records.find(id);
    if (it == m_records.end())
        return;

    it->second.writer.release();
    m_records.erase(it);
}

bool ClipRecorder::checkRecord(const std::string& id) const
{
    return m_records.find(id) != m_records.end();
}
