# The audio formats the engine's assets may hold, as one regular expression.
# The fx-CG50 cannot play any of them, so its asset staging leaves them out and
# a project declaring it is told how many that is: both read this one list.
set(FRIED_AUDIO_FILE_REGEX "\\.([Ww][Aa][Vv]|[Oo][Gg][Gg]|[Mm][Pp]3|[Ff][Ll][Aa][Cc]|[Oo][Pp][Uu][Ss]|[Mm][Oo][Dd]|[Xx][Mm]|[Ss]3[Mm]|[Ii][Tt]|[Mm][Ii][Dd][Ii]?)$")
