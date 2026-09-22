cmake_minimum_required(VERSION 3.20)

project(FriedEngine LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build configuration" FORCE)
endif()

option(FRIED_BUILD_SANDBOX "Build the Haxe -> hxcpp -> CMake pipeline sandbox" ON)

if(FRIED_BUILD_SANDBOX)
    add_subdirectory(sandbox)
endif()
