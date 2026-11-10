cmake_minimum_required(VERSION 3.20)

project(fried_project_editor_player LANGUAGES CXX)

# The editor player of one game, with that game's components in it. The editor
# configures this with FRIED_PROJECT_DIR set, after `haxe editor.hxml` has run
# in the project.
set(FRIED_PROJECT_DIR "" CACHE PATH "The project the editor player is built for")
if(NOT FRIED_PROJECT_DIR)
    message(FATAL_ERROR "FRIED_PROJECT_DIR must name the project to build an editor player for.")
endif()

include(${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/FriedEngine.cmake)

fried_add_game(fried_project_editor_player
    PROJECT_DIR ${FRIED_PROJECT_DIR}
    GENERATED_DIR ${FRIED_PROJECT_DIR}/build/editor/cpp
    EDITOR_PLAYER
)
