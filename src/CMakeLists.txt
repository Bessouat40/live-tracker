# Reusable engine code (no QML registration) -> testable static library
qt_add_library(live_tracker_core STATIC
    camera_source.h           camera_source.cpp
    position/gps.h            position/gps.cpp
    utils/clip_recorder.h     utils/clip_recorder.cpp
    utils/image_painter.h     utils/image_painter.cpp
    detection/detection.h
    detection/yolo_model.h    detection/yolo_model.cpp
    detection/tracker.h       detection/tracker.cpp
)

target_include_directories(live_tracker_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${OpenCV_INCLUDE_DIRS}
)

target_link_libraries(live_tracker_core PUBLIC
    Qt6::Gui
    ${OpenCV_LIBS}
    openvino::runtime
)