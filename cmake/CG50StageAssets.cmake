# Run by fried_add_cg50_g3a() at build time:
#
#   cmake -DENGINE_ASSETS=<dir> -DGAME_ASSETS=<dir> -DDESTINATION=<dir> -P CG50StageAssets.cmake
#
# Copies both imported asset roots, which are already without the audio the
# calculator cannot play (see the audio module in modules.json). The
# destination starts empty every time, so a file deleted from the assets does
# not stay behind to be copied to the calculator.

file(REMOVE_RECURSE "${DESTINATION}")
file(COPY "${ENGINE_ASSETS}/" DESTINATION "${DESTINATION}/engine")
file(COPY "${GAME_ASSETS}/" DESTINATION "${DESTINATION}/game")
