cmake_minimum_required(VERSION 3.16)

project(live-tracker VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick Location Positioning)
find_package(OpenCV REQUIRED)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(applive-tracker
    main.cpp
)

qt_add_qml_module(applive-tracker
    URI live-tracker
    VERSION 1.0
    QML_FILES
        Main.qml
        PositionTypes/PositionItem.qml
        PositionTypes/AddPositionPopup.qml
        MapTypes/MapDisplay.qml
        CameraViewer/CameraViewer.qml
    SOURCES
        src/camera_streaming.h
        src/camera_streaming.cpp
        src/yolo_model.h
    DEPENDENCIES
        QtLocation
        QtPositioning
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

target_include_directories(applive-tracker PRIVATE ${OpenCV_INCLUDE_DIRS} src)
target_link_libraries(applive-tracker
    PRIVATE Qt6::Quick Qt6::Positioning Qt6::Location ${OpenCV_LIBS}
)

include(GNUInstallDirs)
install(TARGETS applive-tracker
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
