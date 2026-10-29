# Haxe on the Nintendo DS without the engine, to measure what the hxcpp
# runtime costs there. Built with devkitPro's toolchain file:
#
#   haxe build.hxml
#   cmake -S . -B build/nds -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/NDS.cmake
#   cmake --build build/nds

cmake_minimum_required(VERSION 3.13)
project(fried_nds_hello C CXX)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE MinSizeRel)
endif()

include("${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake/Hxcpp.cmake")

fried_add_hxcpp_executable(fried_nds_hello "${CMAKE_CURRENT_SOURCE_DIR}/build/cpp")
target_sources(fried_nds_hello PRIVATE native/poc_nds.cpp)
target_include_directories(fried_nds_hello PRIVATE native)
target_link_options(fried_nds_hello PRIVATE "-Wl,-Map=$<TARGET_FILE:fried_nds_hello>.map")

nds_create_rom(fried_nds_hello NAME "Fried NDS PoC" SUBTITLE1 "Haxe runtime test")
