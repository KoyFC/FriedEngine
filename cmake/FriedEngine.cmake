# The entry point a game includes to build against Fried Engine:
#
#   include(${CMAKE_CURRENT_SOURCE_DIR}/engine/cmake/FriedEngine.cmake)
#   fried_add_game(my_game)
#
# Paths resolve from this file, not from CMAKE_SOURCE_DIR, so the engine works
# the same as a submodule of a game and as the top-level project.

get_filename_component(FRIED_ENGINE_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

include("${CMAKE_CURRENT_LIST_DIR}/Hxcpp.cmake")

if(VITA)
    include("${CMAKE_CURRENT_LIST_DIR}/Vita.cmake")
endif()

find_package(SDL2 REQUIRED CONFIG)
find_package(SDL2_image REQUIRED CONFIG)
find_package(SDL2_mixer REQUIRED CONFIG)
find_package(SDL2_ttf REQUIRED CONFIG)

# VitaSDK's freetype and SDL2 packages leave these dependencies unnamed.
if(VITA)
    set_property(TARGET Freetype::Freetype APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES png z bz2
    )
    set_property(TARGET SDL2::SDL2-static APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES pthread
    )
endif()

# The engine's C++ needs nothing from hxcpp, so it is its own library rather
# than sources folded into every game's executable.
if(NOT TARGET fried_engine)
    add_library(fried_engine STATIC
        ${FRIED_ENGINE_DIR}/native/platform/application.cpp
        ${FRIED_ENGINE_DIR}/native/platform/events.cpp
        ${FRIED_ENGINE_DIR}/native/platform/filesystem.cpp
        ${FRIED_ENGINE_DIR}/native/platform/gamepad.cpp
        ${FRIED_ENGINE_DIR}/native/platform/input.cpp
        ${FRIED_ENGINE_DIR}/native/platform/mouse.cpp
        ${FRIED_ENGINE_DIR}/native/platform/window.cpp
        ${FRIED_ENGINE_DIR}/native/graphics/renderer.cpp
        ${FRIED_ENGINE_DIR}/native/graphics/texture.cpp
        ${FRIED_ENGINE_DIR}/native/graphics/font.cpp
        ${FRIED_ENGINE_DIR}/native/audio/sound.cpp
        ${FRIED_ENGINE_DIR}/native/audio/music.cpp
    )

    target_include_directories(fried_engine PUBLIC ${FRIED_ENGINE_DIR}/native)
    target_compile_features(fried_engine PUBLIC cxx_std_17)

    if(VITA)
        target_link_libraries(fried_engine PUBLIC
            SDL2_image::SDL2_image-static
            SDL2_mixer::SDL2_mixer-static
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

    if(VITA)
        file(READ ${_project_file} _project_json)
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${_project_file})
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
