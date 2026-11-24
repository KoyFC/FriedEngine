cmake_minimum_required(VERSION 3.16)
project(fried_import CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

add_executable(fried_import main.cpp import_settings.cpp image_import.cpp audio_import.cpp font_import.cpp)
target_include_directories(fried_import PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../../native/third_party)
