# Runs tools/fried_import over the two asset roots so every platform stages
# the files its sidecars ask for: "sprite.png.import" next to "sprite.png".
#
# The tool is built for the machine doing the build, whatever the target's
# toolchain, and it runs at configure time too, so the imported files exist
# for the packaging steps that list them, as well as before every build so an
# edited asset or sidecar arrives.

# fried_import_assets(<target> <platform> <engine_assets> <game_assets>)
#
# Adds <target>_import and remembers where each root's imported copy is for
# fried_imported_dir(). The copies are under the build tree, a folder per root.
function(fried_import_assets target_name platform engine_assets game_assets)
    get_filename_component(_engine_dir "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/.." ABSOLUTE)
    set(_tool_dir ${CMAKE_BINARY_DIR}/fried_import_tool)
    execute_process(
        COMMAND ${CMAKE_COMMAND} -S ${_engine_dir}/tools/fried_import -B ${_tool_dir}
        RESULT_VARIABLE _configured
        OUTPUT_QUIET
        ERROR_VARIABLE _tool_log
    )
    if(_configured EQUAL 0)
        execute_process(
            COMMAND ${CMAKE_COMMAND} --build ${_tool_dir}
            RESULT_VARIABLE _built
            OUTPUT_QUIET
            ERROR_VARIABLE _tool_log
        )
    endif()
    if(NOT _configured EQUAL 0 OR NOT _built EQUAL 0)
        message(FATAL_ERROR "The asset import tool could not be built for this machine, which takes a C++17 compiler:\n${_tool_log}")
    endif()
    set(_tool ${_tool_dir}/fried_import)
    set(_imported ${CMAKE_BINARY_DIR}/imported)

    foreach(_root engine game)
        set(_source ${${_root}_assets})
        execute_process(
            COMMAND ${_tool} --platform ${platform} --in ${_source} --out ${_imported}/${_root}
            RESULT_VARIABLE _imported_ok
            ERROR_VARIABLE _import_log
        )
        if(_import_log)
            message(WARNING "${_import_log}")
        endif()
        if(NOT _imported_ok EQUAL 0)
            message(FATAL_ERROR "Importing the ${_root} assets failed")
        endif()
        string(MD5 _key "${_source}")
        set_property(GLOBAL PROPERTY FRIED_IMPORTED_${_key} ${_imported}/${_root})
    endforeach()

    add_custom_target(${target_name}_import ALL
        COMMAND ${_tool} --platform ${platform} --in ${engine_assets} --out ${_imported}/engine
        COMMAND ${_tool} --platform ${platform} --in ${game_assets} --out ${_imported}/game
        COMMENT "Importing the assets for ${platform}"
        VERBATIM
    )
    set_property(GLOBAL PROPERTY FRIED_IMPORT_TARGET ${target_name}_import)
endfunction()

# fried_imported_dir(<assets_dir> <out_var>)
#
# Where the imported copy of an asset root is, or the root itself when nothing
# was imported, as for the editor's player.
function(fried_imported_dir assets_dir out_var)
    string(MD5 _key "${assets_dir}")
    get_property(_dir GLOBAL PROPERTY FRIED_IMPORTED_${_key})
    if(_dir)
        set(${out_var} ${_dir} PARENT_SCOPE)
    else()
        set(${out_var} ${assets_dir} PARENT_SCOPE)
    endif()
endfunction()

# fried_depend_on_import(<target>)
#
# Makes a target wait for the import, when there is one.
function(fried_depend_on_import target_name)
    get_property(_import GLOBAL PROPERTY FRIED_IMPORT_TARGET)
    if(_import)
        add_dependencies(${target_name} ${_import})
    endif()
endfunction()
