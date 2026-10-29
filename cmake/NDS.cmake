# Packages an executable built with the devkitPro toolchain as the .nds a
# flashcart or an emulator runs. NINTENDO_DS, which every DS branch in this
# repository keys off, is set by the toolchain file:
#
#   cmake -S . -B build/nds \
#       -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/NDS.cmake
#
# nds_create_rom() comes from that toolchain's platform module, and takes the
# same kind of asset target the 3DS's romfs is.

include("${CMAKE_CURRENT_LIST_DIR}/DevkitProRomfs.cmake")

# fried_add_nds_rom(<target> NAME SUBTITLE1 SUBTITLE2 ICON ENGINE_ASSETS GAME_ASSETS)
#
# The two asset roots are staged into NitroFS under assets/, the layout the PC
# build copies next to the executable.
function(fried_add_nds_rom target_name)
    cmake_parse_arguments(ROM
        ""
        "NAME;SUBTITLE1;SUBTITLE2;ICON;ENGINE_ASSETS;GAME_ASSETS"
        ""
        ${ARGN}
    )

    dkp_add_asset_target(${target_name}_nitrofs "${CMAKE_CURRENT_BINARY_DIR}/nitrofs")

    set(_staged_assets "")
    fried_stage_romfs_assets(${target_name}_nitrofs "${ROM_ENGINE_ASSETS}" "assets/engine" _staged_assets)
    fried_stage_romfs_assets(${target_name}_nitrofs "${ROM_GAME_ASSETS}" "assets/game" _staged_assets)
    set_property(TARGET ${target_name}_nitrofs APPEND PROPERTY DKP_ASSET_FILES ${_staged_assets})

    # Passed none, nds_create_rom() falls back to libnds's own icon, a 32x32
    # BMP as this one has to be.
    set(_icon_argument "")
    if(EXISTS "${ROM_ICON}")
        set(_icon_argument ICON "${ROM_ICON}")
    endif()

    nds_create_rom(${target_name}
        NAME "${ROM_NAME}"
        SUBTITLE1 "${ROM_SUBTITLE1}"
        SUBTITLE2 "${ROM_SUBTITLE2}"
        ${_icon_argument}
        NITROFS ${target_name}_nitrofs
    )
endfunction()
