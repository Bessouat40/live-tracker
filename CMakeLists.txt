cmake_minimum_required(VERSION 3.16)

project(live-tracker VERSION 0.1 LANGUAGES CXX)

set(CMAKE_PREFIX_PATH "/home/uiv22989/Qt/6.11.1/gcc_64")
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick Location Positioning)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appgeo-communication
    main.cpp
)

qt_add_qml_module(appgeo-communication
    URI geo-communication
    VERSION 1.0
    QML_FILES
        Main.qml
        PositionTypes/PositionItem.qml
        PositionTypes/AddPositionPopup.qml
    DEPENDENCIES
        QtLocation
        QtPositioning
)

set_target_properties(appgeo-communication PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appgeo-communication
    PRIVATE Qt6::Quick Qt6::Positioning Qt6::Location
)

include(GNUInstallDirs)
install(TARGETS appgeo-communication
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
