cmake_minimum_required(VERSION 3.16)
project(mistbridge LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)
qt_standard_project_setup()
qt_add_qml_module(mistbridge
    URI org.kumo.mist
    VERSION 1.0
    SOURCES
        mistbridge.cpp
        mistbridge_plugin.cpp
    NO_RESOURCES
)
install(TARGETS mistbridge DESTINATION lib)
install(FILES qmldir DESTINATION lib/qt6/qml/org/kumo/mist)

