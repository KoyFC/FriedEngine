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

# fried_nds_patch_hxcpp(<runtime_sources_var>)
#
# Immix reserves its blocks 32 at a time, which is 1 MB of the DS's 4 MB for a
# game that starts with a few dozen KB of objects; 4 at a time is 128 KB. A
# copy of hxcpp's source with that changed, written into the build tree, is
# what the DS compiles in its place, as the fx-CG50 does for the same define.
function(fried_nds_patch_hxcpp runtime_sources_var)
    set(_runtime_sources ${${runtime_sources_var}})
    set(_patched "${CMAKE_BINARY_DIR}/fried_nds/hxcpp/src/hx/gc/Immix.cpp")

    file(READ "${HXCPP_ROOT}/src/hx/gc/Immix.cpp" _immix)
    set(_from "#define IMMIX_BLOCK_GROUP_BITS  5")
    string(FIND "${_immix}" "${_from}" _found)
    if(_found EQUAL -1)
        message(FATAL_ERROR "hxcpp's src/hx/gc/Immix.cpp no longer contains \"${_from}\", which the DS build patches. cmake/NDS.cmake was written against hxcpp 4.3.2.")
    endif()
    string(REPLACE "${_from}" "#define IMMIX_BLOCK_GROUP_BITS  2" _immix "${_immix}")

    # Rewritten only when the contents change, so configuring again does not
    # rebuild the file.
    file(WRITE "${_patched}.tmp" "${_immix}")
    configure_file("${_patched}.tmp" "${_patched}" COPYONLY)
    file(REMOVE "${_patched}.tmp")

    # The copy still includes its neighbors by relative paths.
    list(REMOVE_ITEM _runtime_sources "${HXCPP_ROOT}/src/hx/gc/Immix.cpp")
    list(APPEND _runtime_sources "${_patched}")
    set_source_files_properties("${_patched}" PROPERTIES
        INCLUDE_DIRECTORIES "${HXCPP_ROOT}/src;${HXCPP_ROOT}/src/hx/gc"
    )

    set(${runtime_sources_var} ${_runtime_sources} PARENT_SCOPE)
endfunction()
