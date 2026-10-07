# The entry point a game includes to build against Fried Engine:
#
#   include(${CMAKE_CURRENT_SOURCE_DIR}/engine/cmake/FriedEngine.cmake)
#   fried_add_game(my_game)
#
# Paths resolve from this file, not from CMAKE_SOURCE_DIR, so the engine works
# the same as a submodule of a game and as the top-level project.

get_filename_component(FRIED_ENGINE_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

include("${CMAKE_CURRENT_LIST_DIR}/Hxcpp.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/ProjectDisplay.cmake")

if(VITA)
    include("${CMAKE_CURRENT_LIST_DIR}/Vita.cmake")
elseif(NINTENDO_SWITCH)
    include("${CMAKE_CURRENT_LIST_DIR}/Switch.cmake")
elseif(NINTENDO_3DS)
    include("${CMAKE_CURRENT_LIST_DIR}/3DS.cmake")
endif()

find_package(SDL2 REQUIRED CONFIG)
find_package(SDL2_ttf REQUIRED CONFIG)

if(NINTENDO_SWITCH)
    fried_find_switch_sdl2_module(SDL2_image fried::sdl2_image)
    fried_find_switch_sdl2_module(SDL2_mixer fried::sdl2_mixer)
else()
    find_package(SDL2_image REQUIRED CONFIG)
    find_package(SDL2_mixer REQUIRED CONFIG)
endif()

# VitaSDK's and devkitPro's 3DS freetype packages leave these dependencies
# unnamed, and so does VitaSDK's SDL2.
if(VITA OR NINTENDO_3DS)
    set_property(TARGET Freetype::Freetype APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES png z bz2
    )
endif()

if(VITA)
    set_property(TARGET SDL2::SDL2-static APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES pthread
    )
endif()

# The 3DS draws through its own GPU library. SDL2's port there has no GPU
# render driver, only a software one.
if(NINTENDO_3DS)
    set(_fried_graphics_backend citro)
else()
    set(_fried_graphics_backend sdl)
endif()

# The engine's C++ needs nothing from hxcpp, so it is its own library rather
# than sources folded into every game's executable.
if(NOT TARGET fried_engine)
    add_library(fried_engine STATIC
        ${FRIED_ENGINE_DIR}/native/last_error.cpp
        ${FRIED_ENGINE_DIR}/native/platform/application.cpp
        ${FRIED_ENGINE_DIR}/native/platform/events.cpp
        ${FRIED_ENGINE_DIR}/native/platform/filesystem.cpp
        ${FRIED_ENGINE_DIR}/native/platform/gamepad.cpp
        ${FRIED_ENGINE_DIR}/native/platform/input.cpp
        ${FRIED_ENGINE_DIR}/native/platform/mouse.cpp
        ${FRIED_ENGINE_DIR}/native/platform/touch.cpp
        ${FRIED_ENGINE_DIR}/native/platform/window.cpp
        ${FRIED_ENGINE_DIR}/native/graphics/renderer_${_fried_graphics_backend}.cpp
        ${FRIED_ENGINE_DIR}/native/graphics/texture_${_fried_graphics_backend}.cpp
        ${FRIED_ENGINE_DIR}/native/graphics/display.cpp
        ${FRIED_ENGINE_DIR}/native/graphics/font.cpp
        ${FRIED_ENGINE_DIR}/native/audio/sound.cpp
        ${FRIED_ENGINE_DIR}/native/audio/music.cpp
    )

    target_include_directories(fried_engine PUBLIC ${FRIED_ENGINE_DIR}/native)
    target_compile_features(fried_engine PUBLIC cxx_std_17)
    set_target_properties(fried_engine PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON
    )

    if(VITA OR NINTENDO_3DS)
        target_link_libraries(fried_engine PUBLIC
            SDL2_image::SDL2_image-static
            SDL2_mixer::SDL2_mixer-static
            SDL2_ttf::SDL2_ttf-static
            SDL2::SDL2
        )
    elseif(NINTENDO_SWITCH)
        target_link_libraries(fried_engine PUBLIC
            fried::sdl2_image
            fried::sdl2_mixer
            SDL2_ttf::SDL2_ttf-static
            SDL2::SDL2
        )
    else()
        target_link_libraries(fried_engine PUBLIC
            SDL2::SDL2
            SDL2_image::SDL2_image
            SDL2_mixer::SDL2_mixer
            SDL2_ttf::SDL2_ttf
        )

        # The executable this archive links into is a PIE.
        set_target_properties(fried_engine PROPERTIES POSITION_INDEPENDENT_CODE ON)
    endif()

    if(VITA OR NINTENDO_3DS)
        target_compile_options(fried_engine PRIVATE -Wno-psabi)
    endif()

    if(NINTENDO_3DS)
        target_link_libraries(fried_engine PUBLIC citro2d citro3d)
    endif()

    add_library(fried::engine ALIAS fried_engine)
endif()

# fried_add_game(<target>)
#
# Builds the game rooted at the calling directory, in the layout every Fried
# project has: build/cpp from its own `haxe build.hxml`, project.fried, assets/
# and, for the Vita, sce_sys/.
function(fried_add_game target_name)
    get_filename_component(_engine_dir "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/.." ABSOLUTE)

    set(_generated_dir ${CMAKE_CURRENT_SOURCE_DIR}/build/cpp)
    set(_project_file ${CMAKE_CURRENT_SOURCE_DIR}/project.fried)
    set(_engine_assets ${_engine_dir}/assets)
    set(_game_assets ${CMAKE_CURRENT_SOURCE_DIR}/assets)

    fried_add_hxcpp_executable(${target_name} ${_generated_dir})
    target_link_libraries(${target_name} PRIVATE fried::engine)

    file(READ ${_project_file} _project_json)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${_project_file})

    if(VITA)
        set(_platform vita)
    elseif(NINTENDO_SWITCH)
        set(_platform switch)
    elseif(NINTENDO_3DS)
        set(_platform 3ds)
    else()
        set(_platform pc)
    endif()

    # The renderer applies the display, so it is compiled into the engine rather than the game.
    fried_read_project_display("${_project_json}" ${_platform} _display_mode _display_width _display_height)
    if(NOT _display_mode STREQUAL "default")
        string(SUBSTRING ${_display_mode} 0 1 _initial)
        string(TOUPPER ${_initial} _initial)
        string(SUBSTRING ${_display_mode} 1 -1 _rest)
        target_compile_definitions(fried_engine PRIVATE
            FRIED_DISPLAY_MODE=FriedDisplayMode::${_initial}${_rest}
            FRIED_DISPLAY_WIDTH=${_display_width}
            FRIED_DISPLAY_HEIGHT=${_display_height}
        )
    endif()

    if(VITA)
        string(JSON _name GET "${_project_json}" name)
        string(JSON _version GET "${_project_json}" version)
        string(JSON _title_id GET "${_project_json}" vita titleId)

        fried_add_vita_vpk(${target_name}
            NAME "${_name}"
            TITLE_ID ${_title_id}
            VERSION ${_version}
            SCE_SYS ${CMAKE_CURRENT_SOURCE_DIR}/sce_sys
            ENGINE_ASSETS ${_engine_assets}
            GAME_ASSETS ${_game_assets}
        )
    elseif(NINTENDO_SWITCH)
        # A .nro's metadata is the identity project.fried already declares, so
        # the Switch adds no keys of its own.
        string(JSON _name GET "${_project_json}" name)
        string(JSON _organization GET "${_project_json}" organization)
        string(JSON _version GET "${_project_json}" version)

        fried_add_switch_nro(${target_name}
            NAME "${_name}"
            AUTHOR "${_organization}"
            VERSION ${_version}
            ICON ${CMAKE_CURRENT_SOURCE_DIR}/switch/icon.jpg
            ENGINE_ASSETS ${_engine_assets}
            GAME_ASSETS ${_game_assets}
        )
    elseif(NINTENDO_3DS)
        # The SMDH carries the same identity as the Switch's .nro. It also has a
        # description line, which shows the version rather than a new key.
        string(JSON _name GET "${_project_json}" name)
        string(JSON _organization GET "${_project_json}" organization)
        string(JSON _version GET "${_project_json}" version)

        fried_add_3ds_3dsx(${target_name}
            NAME "${_name}"
            DESCRIPTION "Version ${_version}"
            AUTHOR "${_organization}"
            ICON ${CMAKE_CURRENT_SOURCE_DIR}/3ds/icon.png
            ENGINE_ASSETS ${_engine_assets}
            GAME_ASSETS ${_game_assets}
        )
    else()
        # Its own ALL target rather than a POST_BUILD command: POST_BUILD only
        # fires when the target relinks, so an edited asset would never arrive.
        add_custom_target(${target_name}_assets ALL
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                ${_engine_assets}
                $<TARGET_FILE_DIR:${target_name}>/assets/engine
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                ${_game_assets}
                $<TARGET_FILE_DIR:${target_name}>/assets/game
            COMMENT "Copying the engine and game asset roots next to the executable"
        )
        add_dependencies(${target_name}_assets ${target_name})
    endif()
endfunction()
