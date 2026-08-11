cmake_minimum_required(VERSION 3.16)

project(live-tracker VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick Location Positioning Multimedia Sql)
find_package(OpenCV REQUIRED)
find_package(OpenVINO REQUIRED)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(
    applive-tracker
    main.cpp
)

set_source_files_properties(
    qml/Singletons/Theme.qml
    qml/Singletons/Clock.qml
    qml/Singletons/FilterState.qml
    qml/Singletons/Selection.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(applive-tracker
    URI live-tracker
    VERSION 1.0
    QML_FILES
        Main.qml
        qml/SharedComponents/ThemedButton.qml
        qml/SharedComponents/Filters.qml
        qml/SharedComponents/VideoPopup.qml
        qml/SharedComponents/MapDisplay.qml
        qml/TimelineComponents/FrescoDot.qml
        qml/TimelineComponents/Panel.qml
        qml/TimelineComponents/TimelineFresco.qml
        qml/TimelineComponents/TimelineView.qml
        qml/TimelineComponents/VideoAnalysisView.qml
        qml/LiveComponents/DetectionsList.qml
        qml/LiveComponents/PositionItem.qml
        qml/LiveComponents/FilterBar.qml
        qml/LiveComponents/LiveView.qml
        qml/LiveComponents/PanelSection.qml
        qml/LiveComponents/TabStrip.qml
        qml/LiveComponents/CameraViewer.qml
        qml/Singletons/Clock.qml
        qml/Singletons/Selection.qml
        qml/Singletons/FilterState.qml
        qml/Singletons/Theme.qml
    SOURCES
        src/camera_source.h
        src/camera_source.cpp
        src/camera_manager.h
        src/utils/clip_recorder.cpp
        src/utils/clip_recorder.h
        src/camera_manager.cpp
        src/detection/detection.h
        src/detection/yolo_model.h
        src/detection/yolo_model.cpp
        src/detection/video_timeline_analyzer.h
        src/detection/video_timeline_analyzer.cpp
        src/position/gps.cpp
        src/position/gps.h
        src/utils/image_painter.h
        src/utils/image_painter.cpp
        src/detection/tracker.h
        src/detection/tracker.cpp
        src/stores/finding_store.h
        src/stores/finding_store.cpp
    DEPENDENCIES
        QtLocation
        QtPositioning
        QtMultimedia
    RESOURCES
        icons/eye-solid-full.svg
)

file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/models DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

set_target_properties(applive-tracker PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_include_directories(applive-tracker PRIVATE
    ${OpenCV_INCLUDE_DIRS}
    src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/stores
    ${CMAKE_CURRENT_SOURCE_DIR}/src/detection
)
target_link_libraries(applive-tracker
    PRIVATE Qt6::Quick Qt6::Positioning Qt6::Location Qt6::Multimedia Qt6::Sql ${OpenCV_LIBS} openvino::runtime
)

include(GNUInstallDirs)
install(TARGETS applive-tracker
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
