#include "tracker.h"
#include <algorithm>

Tracker::Tracker(float iouThreshold, int minHits, int maxAge)
    : m_iouThreshold(iouThreshold), m_minHits(minHits), m_maxAge(maxAge)
{
}

float Tracker::iou(const cv::Rect &a, const cv::Rect &b) {
    const int x1 = std::max(a.x, b.x);
    const int y1 = std::max(a.y, b.y);
    const int x2 = std::min(a.x + a.width, b.x + b.width);
    const int y2 = std::min(a.y + a.height, b.y + b.height);

    const int interW = std::max(0, x2 - x1);
    const int interH = std::max(0, y2 - y1);
    const int intersection = interW * interH;

    const int uni = a.area() + b.area() - intersection;
    return uni > 0 ? static_cast<float>(intersection) / static_cast<float>(uni) : 0.0f;
}

std::vector<Track> Tracker::update(const std::vector<Detection> &detections) {
    for (auto &t : m_tracks)
        t.timeSinceUpdate++;

    std::vector<cv::Rect> detBoxes;
    detBoxes.reserve(detections.size());
    for (const auto &d : detections)
        detBoxes.emplace_back(d.position.x, d.position.y, d.position.w, d.position.h);

    struct Pair { int trackIdx; int detIdx; float iou; };
    std::vector<Pair> pairs;
    for (std::size_t ti = 0; ti < m_tracks.size(); ++ti) {
        for (std::size_t di = 0; di < detections.size(); ++di) {
            if (m_tracks[ti].label != detections[di].label)
                continue;
            const float overlap = iou(m_tracks[ti].box, detBoxes[di]);
            if (overlap >= m_iouThreshold)
                pairs.push_back({static_cast<int>(ti), static_cast<int>(di), overlap});
        }
    }
    std::sort(pairs.begin(), pairs.end(),
              [](const Pair &a, const Pair &b) { return a.iou > b.iou; });

    std::vector<bool> trackUsed(m_tracks.size(), false);
    std::vector<bool> detMatched(detections.size(), false);
    for (const auto &p : pairs) {
        if (trackUsed[p.trackIdx] || detMatched[p.detIdx])
            continue;
        trackUsed[p.trackIdx] = true;
        detMatched[p.detIdx] = true;

        Track &t = m_tracks[p.trackIdx];
        t.box = detBoxes[p.detIdx];
        t.hits++;
        t.timeSinceUpdate = 0;
    }

    for (std::size_t di = 0; di < detections.size(); ++di) {
        if (detMatched[di])
            continue;
        Track t;
        t.id = m_nextId++;
        t.box = detBoxes[di];
        t.label = detections[di].label;
        t.hits = 1;
        t.timeSinceUpdate = 0;
        t.emitted = false;
        m_tracks.push_back(t);
    }

    std::vector<Track> confirmed;
    for (auto &t : m_tracks) {
        if (!t.emitted && t.hits >= m_minHits && t.timeSinceUpdate == 0) {
            t.emitted = true;
            confirmed.push_back(t);
        }
    }

    m_tracks.erase(std::remove_if(m_tracks.begin(), m_tracks.end(),
                                  [this](const Track &t) { return t.timeSinceUpdate > m_maxAge; }),
                   m_tracks.end());

    return confirmed;
}
