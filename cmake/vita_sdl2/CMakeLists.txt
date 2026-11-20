# Builds SDL2 for the Vita with Piglet's OpenGL ES 2 and installs it into CMAKE_INSTALL_PREFIX. VitaDependencies.cmake runs this as a build of its own, once, so a game's build trees link the installed result instead of compiling it again. VitaSDK's SDL2 package has no GL, and SDL leaves its OpenGL ES 2 renderer out of a Piglet build and asks Piglet for a context with no depth buffer, which sdl2-pib.patch changes.
cmake_minimum_required(VERSION 3.20)
project(FriedVitaSdl2 LANGUAGES C CXX)

include(FetchContent)

if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()

set(FRIED_SOURCES_CACHE "" CACHE PATH "Where the source is unpacked once for every build; empty keeps it in this build tree")

# Its own folder, since the patch changes the source and the PC build shares the unpatched one.
set(_release SDL2-2.32.10)
set(_fried_unpacked_marker ".fried-unpacked")
if(FRIED_SOURCES_CACHE)
    set(_source_dir "${FRIED_SOURCES_CACHE}/${_release}-vita")
    if(EXISTS "${_source_dir}/${_fried_unpacked_marker}")
        set(FETCHCONTENT_SOURCE_DIR_SDL2 "${_source_dir}")
    endif()
    set(_source_argument SOURCE_DIR "${_source_dir}")
endif()

find_program(_patch_program patch REQUIRED)
FetchContent_Declare(sdl2
    URL https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.tar.gz
    URL_HASH SHA256=5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165
    ${_source_argument}
    PATCH_COMMAND ${_patch_program} -p1 -i ${CMAKE_CURRENT_LIST_DIR}/sdl2-pib.patch
)

set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
set(CMAKE_POLICY_VERSION_MINIMUM 3.10)

set(SDL_SHARED OFF)
set(SDL_STATIC ON)
set(SDL_TEST OFF)
set(SDL2_DISABLE_SDL2MAIN ON)
set(SDL2_DISABLE_INSTALL OFF)
set(VIDEO_VITA_PIB ON)

FetchContent_MakeAvailable(sdl2)

if(FRIED_SOURCES_CACHE)
    file(TOUCH "${_source_dir}/${_fried_unpacked_marker}")
endif()
