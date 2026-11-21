# Packages an executable built with the devkitPro toolchain as the .3dsx the
# Homebrew Launcher runs. NINTENDO_3DS, which every 3DS branch in this repository
# keys off, is set by the toolchain file:
#
#   cmake -S . -B build/3ds \
#       -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/3DS.cmake
#
# ctr_generate_smdh() and ctr_create_3dsx() come from that toolchain's platform
# module. devkitPro ships no SDL2 for the 3DS: packaging/3ds/ builds it.

include("${CMAKE_CURRENT_LIST_DIR}/DevkitProRomfs.cmake")

# fried_add_3ds_3dsx(<target> NAME DESCRIPTION AUTHOR ICON ENGINE_ASSETS GAME_ASSETS)
#
# The two asset roots are staged under assets/, the layout the PC build copies
# next to the executable, so they are one path shape on every platform.
function(fried_add_3ds_3dsx target_name)
    cmake_parse_arguments(DSX
        ""
        "NAME;DESCRIPTION;AUTHOR;ICON;ENGINE_ASSETS;GAME_ASSETS"
        ""
        ${ARGN}
    )

    dkp_add_asset_target(${target_name}_romfs "${CMAKE_CURRENT_BINARY_DIR}/romfs")

    set(_staged_assets "")
    fried_stage_romfs_assets(${target_name}_romfs "${DSX_ENGINE_ASSETS}" "assets/engine" _staged_assets)
    fried_stage_romfs_assets(${target_name}_romfs "${DSX_GAME_ASSETS}" "assets/game" _staged_assets)

    # ctr_create_3dsx() depends on the files listed here rather than on the
    # folder, so an asset left off this property would pack but never repack.
    set_property(TARGET ${target_name}_romfs APPEND PROPERTY DKP_ASSET_FILES ${_staged_assets})

    # Passed none, ctr_generate_smdh() falls back to libctru's own icon.
    set(_icon_argument "")
    if(EXISTS "${DSX_ICON}")
        set(_icon_argument ICON "${DSX_ICON}")
    endif()

    ctr_generate_smdh(${target_name}.smdh
        NAME "${DSX_NAME}"
        DESCRIPTION "${DSX_DESCRIPTION}"
        AUTHOR "${DSX_AUTHOR}"
        ${_icon_argument}
    )

    ctr_create_3dsx(${target_name}
        SMDH ${target_name}.smdh
        ROMFS ${target_name}_romfs
    )
endfunction()
