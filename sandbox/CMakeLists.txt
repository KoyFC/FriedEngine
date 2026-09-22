# Pipeline sandbox: proves Haxe -> hxcpp -> generated C++ -> CMake ->
# executable end to end. This is not the engine; see ARCHITECTURE.md.
#
# Prerequisite (not run by CMake yet): from this directory,
#   haxe build.hxml
# which generates build/cpp/ from src/Main.hx.

include(${CMAKE_SOURCE_DIR}/cmake/Hxcpp.cmake)

set(FRIED_SANDBOX_GENERATED_DIR ${CMAKE_CURRENT_SOURCE_DIR}/build/cpp)

fried_add_hxcpp_executable(fried_sandbox ${FRIED_SANDBOX_GENERATED_DIR})
