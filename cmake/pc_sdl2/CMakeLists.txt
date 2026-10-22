# Builds SDL2 and its three companions from source and installs them into CMAKE_INSTALL_PREFIX. PcDependencies.cmake runs this as a build of its own, once per compiler and configuration, so a game's build trees link the installed result instead of compiling it again.
cmake_minimum_required(VERSION 3.20)
project(FriedPcSdl2 LANGUAGES C CXX)

include(FetchContent)

if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()

set(FRIED_SOURCES_CACHE "" CACHE PATH "Where the sources are unpacked once for every build; empty keeps them in this build tree")

set(_fried_unpacked_marker ".fried-unpacked")

# A source unpacked by an earlier build is used as it is, with nothing downloaded.
function(_fried_declare_pc_dependency name release url sha256)
    if(NOT FRIED_SOURCES_CACHE)
        FetchContent_Declare(${name} URL ${url} URL_HASH SHA256=${sha256})
        return()
    endif()

    set(_source_dir "${FRIED_SOURCES_CACHE}/${release}")
    set(_fried_cached_sources ${_fried_cached_sources} "${_source_dir}" PARENT_SCOPE)
    if(EXISTS "${_source_dir}/${_fried_unpacked_marker}")
        string(TOUPPER ${name} _upper_name)
        set(FETCHCONTENT_SOURCE_DIR_${_upper_name} "${_source_dir}" PARENT_SCOPE)
    endif()
    FetchContent_Declare(${name} URL ${url} URL_HASH SHA256=${sha256} SOURCE_DIR "${_source_dir}")
endfunction()

# Release tarballs, since SDL2_ttf's is the one that bundles FreeType.
_fried_declare_pc_dependency(sdl2 SDL2-2.32.10
    https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.tar.gz
    5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165
)
_fried_declare_pc_dependency(sdl2_image SDL2_image-2.8.12
    https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.12/SDL2_image-2.8.12.tar.gz
    393f5efb50536ec13ca4f4affb69cc9966d3c3f969e6c5e701faddf9f9785381
)
_fried_declare_pc_dependency(sdl2_mixer SDL2_mixer-2.8.2
    https://github.com/libsdl-org/SDL_mixer/releases/download/release-2.8.2/SDL2_mixer-2.8.2.tar.gz
    938dff531d00ace2296557a6599abe6f34599e2f34f0a4a08a397e2ccac8b8f7
)
_fried_declare_pc_dependency(sdl2_ttf SDL2_ttf-2.24.0
    https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.24.0/SDL2_ttf-2.24.0.tar.gz
    0b2bf1e7b6568adbdbc9bb924643f79d9dedafe061fa1ed687d1d9ac4e453bfd
)

# SDL2's and FreeType's declared CMake versions predate these policies.
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
set(CMAKE_POLICY_DEFAULT_CMP0091 NEW)
set(CMAKE_POLICY_VERSION_MINIMUM 3.10)

set(BUILD_SHARED_LIBS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(SDL_SHARED OFF)
set(SDL_STATIC ON)
set(SDL_TEST OFF)
set(SDL2_DISABLE_SDL2MAIN ON)
set(SDL2_DISABLE_INSTALL OFF)

set(SDL2IMAGE_INSTALL ON)
set(SDL2IMAGE_VENDORED OFF)
set(SDL2IMAGE_SAMPLES OFF)
set(SDL2IMAGE_BACKEND_STB ON)
set(SDL2IMAGE_PNG ON)
set(SDL2IMAGE_JPG ON)
foreach(_unused_image_format AVIF BMP GIF JXL LBM PCX PNM QOI SVG TGA TIF WEBP XCF XPM XV)
    set(SDL2IMAGE_${_unused_image_format} OFF)
endforeach()

set(SDL2MIXER_INSTALL ON)
set(SDL2MIXER_VENDORED OFF)
set(SDL2MIXER_SAMPLES OFF)
set(SDL2MIXER_WAVE ON)
set(SDL2MIXER_VORBIS STB)
set(SDL2MIXER_MP3 ON)
set(SDL2MIXER_MP3_MINIMP3 ON)
set(SDL2MIXER_MP3_MPG123 OFF)
foreach(_unused_mixer_feature CMD FLAC GME MOD MIDI OPUS WAVPACK)
    set(SDL2MIXER_${_unused_mixer_feature} OFF)
endforeach()

set(SDL2TTF_INSTALL ON)
set(SDL2TTF_VENDORED ON)
set(SDL2TTF_SAMPLES OFF)
set(SDL2TTF_HARFBUZZ OFF)

FetchContent_MakeAvailable(sdl2 sdl2_image sdl2_mixer sdl2_ttf)

# Only a source that unpacked completely is reused by the next build.
if(FRIED_SOURCES_CACHE)
    foreach(_source_dir IN LISTS _fried_cached_sources)
        file(TOUCH "${_source_dir}/${_fried_unpacked_marker}")
    endforeach()
endif()
