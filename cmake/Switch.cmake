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
    fried_stage_switch_assets(${target_name}_romfs "${NRO_ENGINE_ASSETS}" "assets/engine" _staged_assets)
    fried_stage_switch_assets(${target_name}_romfs "${NRO_GAME_ASSETS}" "assets/game" _staged_assets)

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

# Stages every file under <source_dir> into <asset_target>'s folder at
# <destination>, appending the staged paths to <out_var>. elf2nro takes one
# directory rather than the source/destination pairs vita_create_vpk() takes, so
# the layout is built in the build tree first.
function(fried_stage_switch_assets asset_target source_dir destination out_var)
    get_target_property(_romfs_dir ${asset_target} DKP_ASSET_FOLDER)

    file(GLOB_RECURSE _assets CONFIGURE_DEPENDS "${source_dir}/*")

    set(_files ${${out_var}})
    foreach(_asset ${_assets})
        file(RELATIVE_PATH _relative "${source_dir}" "${_asset}")
        set(_staged "${_romfs_dir}/${destination}/${_relative}")
        get_filename_component(_staged_dir "${_staged}" DIRECTORY)

        add_custom_command(
            OUTPUT "${_staged}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${_staged_dir}"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_asset}" "${_staged}"
            DEPENDS "${_asset}"
            COMMENT "Staging ${destination}/${_relative} into the romfs"
            VERBATIM
        )

        list(APPEND _files "${_staged}")
    endforeach()

    set(${out_var} ${_files} PARENT_SCOPE)
endfunction()
