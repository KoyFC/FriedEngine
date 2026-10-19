include(FetchContent)

if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()

option(FRIED_SYSTEM_SDL2 "Link the installed SDL2 libraries on PC instead of building them from source" OFF)

function(fried_add_pc_sdl2 out_link_targets)
    if(FRIED_SYSTEM_SDL2)
        find_package(SDL2 REQUIRED CONFIG)
        find_package(SDL2_image REQUIRED CONFIG)
        find_package(SDL2_mixer REQUIRED CONFIG)
        find_package(SDL2_ttf REQUIRED CONFIG)

        set(${out_link_targets}
            SDL2::SDL2
            SDL2_image::SDL2_image
            SDL2_mixer::SDL2_mixer
            SDL2_ttf::SDL2_ttf
            PARENT_SCOPE
        )
        return()
    endif()

    # Release tarballs, since SDL2_ttf's is the one that bundles FreeType.
    FetchContent_Declare(sdl2
        URL https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.tar.gz
        URL_HASH SHA256=5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165
    )
    FetchContent_Declare(sdl2_image
        URL https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.12/SDL2_image-2.8.12.tar.gz
        URL_HASH SHA256=393f5efb50536ec13ca4f4affb69cc9966d3c3f969e6c5e701faddf9f9785381
    )
    FetchContent_Declare(sdl2_mixer
        URL https://github.com/libsdl-org/SDL_mixer/releases/download/release-2.8.2/SDL2_mixer-2.8.2.tar.gz
        URL_HASH SHA256=938dff531d00ace2296557a6599abe6f34599e2f34f0a4a08a397e2ccac8b8f7
    )
    FetchContent_Declare(sdl2_ttf
        URL https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.24.0/SDL2_ttf-2.24.0.tar.gz
        URL_HASH SHA256=0b2bf1e7b6568adbdbc9bb924643f79d9dedafe061fa1ed687d1d9ac4e453bfd
    )

    # SDL2's and FreeType's declared CMake versions predate both policies.
    set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
    set(CMAKE_POLICY_VERSION_MINIMUM 3.10)

    set(BUILD_SHARED_LIBS OFF)
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)

    set(SDL_SHARED OFF)
    set(SDL_STATIC ON)
    set(SDL_TEST OFF)
    set(SDL2_DISABLE_SDL2MAIN ON)

    set(SDL2IMAGE_VENDORED OFF)
    set(SDL2IMAGE_SAMPLES OFF)
    set(SDL2IMAGE_BACKEND_STB ON)
    set(SDL2IMAGE_PNG ON)
    set(SDL2IMAGE_JPG ON)
    foreach(_unused_image_format AVIF BMP GIF JXL LBM PCX PNM QOI SVG TGA TIF WEBP XCF XPM XV)
        set(SDL2IMAGE_${_unused_image_format} OFF)
    endforeach()

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

    set(SDL2TTF_VENDORED ON)
    set(SDL2TTF_SAMPLES OFF)
    set(SDL2TTF_HARFBUZZ OFF)

    FetchContent_MakeAvailable(sdl2 sdl2_image sdl2_mixer sdl2_ttf)

    set(${out_link_targets}
        SDL2_image::SDL2_image-static
        SDL2_mixer::SDL2_mixer-static
        SDL2_ttf::SDL2_ttf-static
        SDL2::SDL2-static
        PARENT_SCOPE
    )
endfunction()
