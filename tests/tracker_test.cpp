#include <gtest/gtest.h>

#include "detection/detection.h"
#include "detection/tracker.h"

namespace {

Detection det(const std::string &label, int x, int y, int w = 20, int h = 20) {
    return Detection{0, label, 0.9f, DetectionPosition{x, y, w, h}};
}

} // namespace

TEST(Tracker, DoesNotConfirmBeforeMinHits) {
    Tracker tracker(0.3f, 3, 15);
    const Detection d = det("person", 10, 10);

    EXPECT_TRUE(tracker.update({d}).empty()); // hits = 1
    EXPECT_TRUE(tracker.update({d}).empty()); // hits = 2
}

TEST(Tracker, ConfirmsAfterMinHits) {
    Tracker tracker(0.3f, 3, 15);
    const Detection d = det("person", 10, 10);

    tracker.update({d});
    tracker.update({d});
    const std::vector<Track> confirmed = tracker.update({d}); // hits = 3

    ASSERT_EQ(confirmed.size(), 1u);
    EXPECT_EQ(confirmed[0].label, "person");
    EXPECT_EQ(confirmed[0].hits, 3);
}

TEST(Tracker, ConfirmsEachTrackOnlyOnce) {
    Tracker tracker(0.3f, 3, 15);
    const Detection d = det("person", 10, 10);

    tracker.update({d});
    tracker.update({d});
    ASSERT_EQ(tracker.update({d}).size(), 1u);

    EXPECT_TRUE(tracker.update({d}).empty()) << "already emitted track is not re-emitted";
}

TEST(Tracker, KeepsDifferentLabelsAsSeparateTracks) {
    Tracker tracker(0.3f, 1, 15);
    // Same box, different labels -> must not be matched together.
    const std::vector<Track> confirmed =
        tracker.update({det("person", 10, 10), det("car", 10, 10)});

    EXPECT_EQ(confirmed.size(), 2u);
    EXPECT_NE(confirmed[0].id, confirmed[1].id);
}

TEST(Tracker, DoesNotMatchNonOverlappingBoxes) {
    Tracker tracker(0.3f, 1, 15);
    // Same label but disjoint boxes -> two distinct tracks.
    const std::vector<Track> confirmed =
        tracker.update({det("person", 0, 0), det("person", 500, 500)});

    EXPECT_EQ(confirmed.size(), 2u);
}

TEST(Tracker, DropsTrackAfterMaxAge) {
    Tracker tracker(0.3f, 1, 3);
    const Detection d = det("person", 10, 10);

    ASSERT_EQ(tracker.update({d}).size(), 1u); // track id 0, emitted

    // No detections long enough to exceed maxAge -> the track is dropped.
    for (int i = 0; i < 4; ++i)
        tracker.update({});

    // Same box reappears: the old track is gone, so a brand new one is created.
    const std::vector<Track> confirmed = tracker.update({d});
    ASSERT_EQ(confirmed.size(), 1u);
    EXPECT_EQ(confirmed[0].id, 1);
}
