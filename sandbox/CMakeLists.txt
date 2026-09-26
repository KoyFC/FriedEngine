cmake_minimum_required(VERSION 3.20)

project(fried_sandbox LANGUAGES CXX)

# The same entry point an external game uses; only the path to it differs.
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/FriedEngine.cmake)

fried_add_game(fried_sandbox)
