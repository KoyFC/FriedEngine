include(${CMAKE_SOURCE_DIR}/cmake/Hxcpp.cmake)

set(FRIED_SANDBOX_GENERATED_DIR ${CMAKE_CURRENT_SOURCE_DIR}/build/cpp)

fried_add_hxcpp_executable(fried_sandbox ${FRIED_SANDBOX_GENERATED_DIR})

find_package(SDL2 REQUIRED CONFIG)
find_package(SDL2_image REQUIRED CONFIG)
find_package(SDL2_mixer REQUIRED CONFIG)
find_package(SDL2_ttf REQUIRED CONFIG)

target_sources(fried_sandbox PRIVATE
    ${CMAKE_SOURCE_DIR}/native/platform/application.cpp
    ${CMAKE_SOURCE_DIR}/native/platform/events.cpp
    ${CMAKE_SOURCE_DIR}/native/platform/filesystem.cpp
    ${CMAKE_SOURCE_DIR}/native/platform/gamepad.cpp
    ${CMAKE_SOURCE_DIR}/native/platform/input.cpp
    ${CMAKE_SOURCE_DIR}/native/platform/mouse.cpp
    ${CMAKE_SOURCE_DIR}/native/platform/window.cpp
    ${CMAKE_SOURCE_DIR}/native/graphics/renderer.cpp
    ${CMAKE_SOURCE_DIR}/native/graphics/texture.cpp
    ${CMAKE_SOURCE_DIR}/native/graphics/font.cpp
    ${CMAKE_SOURCE_DIR}/native/audio/sound.cpp
    ${CMAKE_SOURCE_DIR}/native/audio/music.cpp
)
target_include_directories(fried_sandbox PRIVATE ${CMAKE_SOURCE_DIR}/native)

# VitaSDK builds SDL2's companion libraries as static only, under their own
# target names, and its freetype and SDL2 packages leave dependencies unnamed.
if(VITA)
    set_property(TARGET Freetype::Freetype APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES png z bz2
    )
    set_property(TARGET SDL2::SDL2-static APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES pthread
    )

    target_link_libraries(fried_sandbox PRIVATE
        SDL2_image::SDL2_image-static
        SDL2_mixer::SDL2_mixer-static
        SDL2_ttf::SDL2_ttf-static
        SDL2::SDL2
    )

    include(${CMAKE_SOURCE_DIR}/cmake/Vita.cmake)

    fried_add_vita_vpk(fried_sandbox
        NAME "Fried Sandbox"
        TITLE_ID FRIE00001
        VERSION 01.00
        SCE_SYS ${CMAKE_CURRENT_SOURCE_DIR}/sce_sys
        ENGINE_ASSETS ${CMAKE_SOURCE_DIR}/assets
        GAME_ASSETS ${CMAKE_CURRENT_SOURCE_DIR}/assets
    )
else()
    target_link_libraries(fried_sandbox PRIVATE
        SDL2::SDL2
        SDL2_image::SDL2_image
        SDL2_mixer::SDL2_mixer
        SDL2_ttf::SDL2_ttf
    )

    # A separate always-run target rather than a POST_BUILD command on the
    # executable: POST_BUILD only fires when the target relinks, so an added or
    # edited asset would never reach the build tree on its own.
    add_custom_target(fried_sandbox_assets ALL
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            ${CMAKE_SOURCE_DIR}/assets
            $<TARGET_FILE_DIR:fried_sandbox>/assets/engine
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            ${CMAKE_CURRENT_SOURCE_DIR}/assets
            $<TARGET_FILE_DIR:fried_sandbox>/assets/game
        COMMENT "Copying the engine and game asset roots next to the executable"
    )
    add_dependencies(fried_sandbox_assets fried_sandbox)
endif()
