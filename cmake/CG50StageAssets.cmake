# Run by fried_add_cg50_g3a() at build time:
#
#   cmake -DENGINE_ASSETS=<dir> -DGAME_ASSETS=<dir> -DDESTINATION=<dir> -P CG50StageAssets.cmake
#
# Copies both asset roots without their audio, which the calculator cannot
# play. The destination starts empty every time, so a file deleted from the
# assets, or one this script has since learned to leave out, does not stay
# behind to be copied to the calculator.

set(_audio "\\.([Ww][Aa][Vv]|[Oo][Gg][Gg]|[Mm][Pp]3|[Ff][Ll][Aa][Cc]|[Oo][Pp][Uu][Ss]|[Mm][Oo][Dd]|[Xx][Mm]|[Ss]3[Mm]|[Ii][Tt]|[Mm][Ii][Dd][Ii]?)$")

file(REMOVE_RECURSE "${DESTINATION}")
file(COPY "${ENGINE_ASSETS}/" DESTINATION "${DESTINATION}/engine" REGEX "${_audio}" EXCLUDE)
file(COPY "${GAME_ASSETS}/" DESTINATION "${DESTINATION}/game" REGEX "${_audio}" EXCLUDE)
