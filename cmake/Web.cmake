# Packages an executable built with Emscripten as the page the browser runs.
# EMSCRIPTEN, which every web branch in this repository keys off, is set by the
# toolchain file:
#
#   emcmake cmake -S . -B build/web
#
# SDL2 and its companions are Emscripten ports: emcc builds them from the flags
# below the first time they are asked for, so there is nothing to find.

set(FRIED_WEB_SDL_FLAGS
    -sUSE_SDL=2
    -sUSE_SDL_IMAGE=2
    "-sSDL2_IMAGE_FORMATS=[\"png\"]"
    -sUSE_SDL_MIXER=2
    "-sSDL2_MIXER_FORMATS=[\"ogg\",\"wav\"]"
    -sUSE_SDL_TTF=2
)

# fried_add_web_page(<target> NAME ENGINE_ASSETS GAME_ASSETS)
#
# The two asset roots are embedded under assets/, the layout the PC build copies
# next to the executable, so they are one path shape on every platform.
function(fried_add_web_page target_name)
    cmake_parse_arguments(PAGE "" "NAME;ENGINE_ASSETS;GAME_ASSETS" "" ${ARGN})

    set_target_properties(${target_name} PROPERTIES SUFFIX ".html")

    # The loop in Application.run() hands control back to the browser for every
    # frame, which the Haxe stack cannot do without Asyncify unwinding it.
    target_link_options(${target_name} PRIVATE
        ${FRIED_WEB_SDL_FLAGS}
        -sASYNCIFY
        -sALLOW_MEMORY_GROWTH
        -sEXIT_RUNTIME
        "SHELL:--shell-file ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/web/shell.html"
        "SHELL:--preload-file ${PAGE_ENGINE_ASSETS}@/assets/engine"
        "SHELL:--preload-file ${PAGE_GAME_ASSETS}@/assets/game"
    )

    set_property(TARGET ${target_name} APPEND PROPERTY LINK_DEPENDS
        ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/web/shell.html ${PAGE_ENGINE_ASSETS} ${PAGE_GAME_ASSETS}
    )
endfunction()
