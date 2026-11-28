cmake_minimum_required(VERSION 3.20)

project(fried_project_editor_player LANGUAGES CXX)

# The editor player of one game, with that game's nodes in it. The editor
# configures this with FRIED_PROJECT_DIR set, after `haxe editor.hxml` has run
# in the project.
set(FRIED_PROJECT_DIR "" CACHE PATH "The project the editor player is built for")
if(NOT FRIED_PROJECT_DIR)
    message(FATAL_ERROR "FRIED_PROJECT_DIR must name the project to build an editor player for.")
endif()

# The editor player is rebuilt for every project and every change, so it trades
# speed for build time. None of this reaches a game: it is this build tree's.
if(MSVC)
    set(CMAKE_C_FLAGS_RELEASE "/O1 /Ob1 /DNDEBUG")
    set(CMAKE_CXX_FLAGS_RELEASE "/O1 /Ob1 /DNDEBUG")
    # Visual Studio's generator builds one file at a time inside a target without it.
    add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:/MP>")
else()
    set(CMAKE_C_FLAGS_RELEASE "-O1 -DNDEBUG")
    set(CMAKE_CXX_FLAGS_RELEASE "-O1 -DNDEBUG")
endif()

# Visual Studio's generators ignore compiler launchers, so ccache only helps with the others.
if(NOT CMAKE_GENERATOR MATCHES "Visual Studio")
    find_program(FRIED_CCACHE_PROGRAM ccache)
    if(FRIED_CCACHE_PROGRAM)
        # Relative to the home folder and without the working directory, so one project's objects are found by another's, and with the precompiled header allowed.
        if(WIN32)
            set(_fried_home "$ENV{USERPROFILE}")
        else()
            set(_fried_home "$ENV{HOME}")
        endif()
        set(_fried_ccache_launcher "${CMAKE_COMMAND}" -E env
            CCACHE_NOHASHDIR=1 CCACHE_SLOPPINESS=pch_defines,time_macros
            "${FRIED_CCACHE_PROGRAM}")
        if(_fried_home)
            list(INSERT _fried_ccache_launcher 3 "CCACHE_BASEDIR=${_fried_home}")
        endif()
        set(CMAKE_C_COMPILER_LAUNCHER "${_fried_ccache_launcher}")
        set(CMAKE_CXX_COMPILER_LAUNCHER "${_fried_ccache_launcher}")
    endif()
endif()

if(NOT MSVC AND NOT WIN32)
    include(CheckLinkerFlag)
    check_linker_flag(CXX -fuse-ld=lld FRIED_LLD_AVAILABLE)
    if(FRIED_LLD_AVAILABLE)
        add_link_options(-fuse-ld=lld)
    endif()
endif()

include(${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/FriedEngine.cmake)

fried_add_game(fried_project_editor_player
    PROJECT_DIR ${FRIED_PROJECT_DIR}
    GENERATED_DIR ${FRIED_PROJECT_DIR}/build/editor/cpp
    EDITOR_PLAYER
)
