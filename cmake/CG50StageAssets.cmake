# Run by fried_add_cg50_g3a() at build time:
#
#   cmake -DENGINE_ASSETS=<dir> -DGAME_ASSETS=<dir> -DDESTINATION=<dir> -P CG50StageAssets.cmake
#
# Copies both asset roots without their audio, which the calculator cannot
# play. The destination starts empty every time, so a file deleted from the
# assets, or one this script has since learned to leave out, does not stay
# behind to be copied to the calculator.

include("${CMAKE_CURRENT_LIST_DIR}/AudioFiles.cmake")

file(REMOVE_RECURSE "${DESTINATION}")
file(COPY "${ENGINE_ASSETS}/" DESTINATION "${DESTINATION}/engine" REGEX "${FRIED_AUDIO_FILE_REGEX}" EXCLUDE)
file(COPY "${GAME_ASSETS}/" DESTINATION "${DESTINATION}/game" REGEX "${FRIED_AUDIO_FILE_REGEX}" EXCLUDE)
