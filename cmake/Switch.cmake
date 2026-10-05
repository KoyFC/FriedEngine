# Packages an executable built with the devkitPro toolchain as the .nro the
# console runs, and finds the two SDL2 companion libraries that describe
# themselves with pkg-config there. NINTENDO_SWITCH, which every Switch branch in
# this repository keys off, is set by the toolchain file:
#
#   cmake -S . -B build/switch \
#       -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/Switch.cmake
#
# nx_generate_nacp() and nx_create_nro() come from that toolchain's platform
# module, so unlike the Vita there is no SDK file to include here.

include("${CMAKE_CURRENT_LIST_DIR}/DevkitProRomfs.cmake")

find_package(PkgConfig REQUIRED)

# devkitPro ships CMake package configs for SDL2 and SDL2_ttf but not for
# SDL2_image or SDL2_mixer. The static answer is the one to read: both leave
# their real dependencies in Requires.private, which pkg-config prints only for
# a static link.
function(fried_find_switch_sdl2_module module target_name)
    pkg_check_modules(${module} REQUIRED ${module})

    add_library(${target_name} INTERFACE IMPORTED GLOBAL)
    set_property(TARGET ${target_name} APPEND PROPERTY
        INTERFACE_INCLUDE_DIRECTORIES ${${module}_STATIC_INCLUDE_DIRS}
    )
    set_property(TARGET ${target_name} APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES ${${module}_STATIC_LDFLAGS}
    )
endfunction()

# fried_add_switch_nro(<target> NAME AUTHOR VERSION ICON ENGINE_ASSETS GAME_ASSETS)
#
# The two asset roots are staged under assets/, the layout the PC build copies
# next to the executable, so they are one path shape on every platform.
function(fried_add_switch_nro target_name)
    cmake_parse_arguments(NRO
        ""
        "NAME;AUTHOR;VERSION;ICON;ENGINE_ASSETS;GAME_ASSETS"
        ""
        ${ARGN}
    )

    dkp_add_asset_target(${target_name}_romfs "${CMAKE_CURRENT_BINARY_DIR}/romfs")

    set(_staged_assets "")
    fried_stage_romfs_assets(${target_name}_romfs "${NRO_ENGINE_ASSETS}" "assets/engine" _staged_assets)
    fried_stage_romfs_assets(${target_name}_romfs "${NRO_GAME_ASSETS}" "assets/game" _staged_assets)

    # nx_create_nro() depends on the files listed here rather than on the folder,
    # so an asset left off this property would pack but never repack.
    set_property(TARGET ${target_name}_romfs APPEND PROPERTY DKP_ASSET_FILES ${_staged_assets})

    nx_generate_nacp(${target_name}.nacp
        NAME "${NRO_NAME}"
        AUTHOR "${NRO_AUTHOR}"
        VERSION "${NRO_VERSION}"
    )

    # Passed none, nx_create_nro() falls back to libnx's own icon.
    set(_icon_argument "")
    if(EXISTS "${NRO_ICON}")
        set(_icon_argument ICON "${NRO_ICON}")
    endif()

    nx_create_nro(${target_name}
        NACP ${target_name}.nacp
        ROMFS ${target_name}_romfs
        ${_icon_argument}
    )
endfunction()
