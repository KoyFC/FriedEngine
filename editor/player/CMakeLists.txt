cmake_minimum_required(VERSION 3.20)

project(fried_editor_player LANGUAGES CXX)

include(${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/FriedEngine.cmake)

fried_add_game(fried_editor_player)
