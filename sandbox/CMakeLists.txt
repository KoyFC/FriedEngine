include(${CMAKE_SOURCE_DIR}/cmake/Hxcpp.cmake)

set(FRIED_SANDBOX_GENERATED_DIR ${CMAKE_CURRENT_SOURCE_DIR}/build/cpp)

fried_add_hxcpp_executable(fried_sandbox ${FRIED_SANDBOX_GENERATED_DIR})

find_package(SDL2 REQUIRED CONFIG)

target_sources(fried_sandbox PRIVATE ${CMAKE_SOURCE_DIR}/native/sdl_proof.cpp)
target_include_directories(fried_sandbox PRIVATE ${CMAKE_SOURCE_DIR}/native)
target_link_libraries(fried_sandbox PRIVATE SDL2::SDL2)
