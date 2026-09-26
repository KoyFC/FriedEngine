# The same entry point an external game uses; only the path to it differs.
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/FriedEngine.cmake)

fried_add_game(fried_sandbox)
