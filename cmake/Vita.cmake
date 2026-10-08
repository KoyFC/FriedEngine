# Packages an executable built with the VitaSDK toolchain as the .self and .vpk
# the console runs. VITA, which every Vita branch in this repository keys off,
# is set by the toolchain file:
#
#   cmake -S . -B build/vita \
#       -DCMAKE_TOOLCHAIN_FILE=$VITASDK/share/vita.toolchain.cmake

include("${VITASDK}/share/vita.cmake" REQUIRED)

# The two asset roots are packed under assets/, the layout the PC build copies
# next to the executable, so they are one path shape on every platform.
function(fried_add_vita_vpk target_name)
    cmake_parse_arguments(VPK
        ""
        "NAME;TITLE_ID;VERSION;SCE_SYS;ENGINE_ASSETS;GAME_ASSETS"
        ""
        ${ARGN}
    )

    vita_create_self(${target_name}.self ${target_name})

    set(_vpk_files "")

    # The splash shown while the game boots is optional. A glob rather than
    # if(EXISTS) so adding or removing it later reconfigures on its own.
    file(GLOB _pic0 CONFIGURE_DEPENDS "${VPK_SCE_SYS}/pic0.png")
    if(_pic0)
        list(APPEND _vpk_files FILE "${_pic0}" sce_sys/pic0.png)
    endif()

    fried_collect_vita_assets("${VPK_ENGINE_ASSETS}" "assets/engine" _vpk_files)
    fried_collect_vita_assets("${VPK_GAME_ASSETS}" "assets/game" _vpk_files)

    vita_create_vpk(${target_name}.vpk ${VPK_TITLE_ID} ${target_name}.self
        NAME "${VPK_NAME}"
        VERSION ${VPK_VERSION}
        FILE "${VPK_SCE_SYS}/icon0.png" sce_sys/icon0.png
        FILE "${VPK_SCE_SYS}/livearea/contents/bg.png" sce_sys/livearea/contents/bg.png
        FILE "${VPK_SCE_SYS}/livearea/contents/startup.png" sce_sys/livearea/contents/startup.png
        FILE "${VPK_SCE_SYS}/livearea/contents/template.xml" sce_sys/livearea/contents/template.xml
        ${_vpk_files}
    )
endfunction()

# Appends every file under <source_dir> to <out_var> as the FILE <src> <dest>
# pairs vita_create_vpk() takes, rooted at <destination>.
function(fried_collect_vita_assets source_dir destination out_var)
    file(GLOB_RECURSE _assets CONFIGURE_DEPENDS "${source_dir}/*")

    set(_files ${${out_var}})
    foreach(_asset ${_assets})
        file(RELATIVE_PATH _relative "${source_dir}" "${_asset}")
        list(APPEND _files FILE "${_asset}" "${destination}/${_relative}")
    endforeach()

    set(${out_var} ${_files} PARENT_SCOPE)
endfunction()
