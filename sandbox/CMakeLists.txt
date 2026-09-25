include(${CMAKE_SOURCE_DIR}/cmake/Hxcpp.cmake)

set(FRIED_SANDBOX_GENERATED_DIR ${CMAKE_CURRENT_SOURCE_DIR}/build/cpp)

fried_add_hxcpp_executable(fried_sandbox ${FRIED_SANDBOX_GENERATED_DIR})

find_package(SDL2 REQUIRED CONFIG)
find_package(SDL2_image REQUIRED CONFIG)
find_package(SDL2_mixer REQUIRED CONFIG)
find_package(SDL2_ttf REQUIRED CONFIG)

target_sources(fried_sandbox PRIVATE
    ${CMAKE_SOURCE_DIR}/native/application.cpp
    ${CMAKE_SOURCE_DIR}/native/events.cpp
    ${CMAKE_SOURCE_DIR}/native/input.cpp
    ${CMAKE_SOURCE_DIR}/native/mouse.cpp
    ${CMAKE_SOURCE_DIR}/native/window.cpp
    ${CMAKE_SOURCE_DIR}/native/filesystem.cpp
)
target_include_directories(fried_sandbox PRIVATE ${CMAKE_SOURCE_DIR}/native)
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
