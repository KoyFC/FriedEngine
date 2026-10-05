# Stages every file under <source_dir> into <asset_target>'s folder at
# <destination>, appending the staged paths to <out_var>. devkitPro's packaging
# tools take one romfs directory rather than the source/destination pairs
# vita_create_vpk() takes, so the layout is built in the build tree first.
function(fried_stage_romfs_assets asset_target source_dir destination out_var)
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
