add_executable(live_tracker_tests
    camera_source_test.cpp
)

target_link_libraries(live_tracker_tests PRIVATE
    live_tracker_core
    GTest::gtest_main
)

include(GoogleTest)
gtest_discover_tests(live_tracker_tests
    DISCOVERY_MODE PRE_TEST
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)