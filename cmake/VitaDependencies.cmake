# SDL2 for the Vita, built once from source with Piglet's OpenGL ES 2 (see vita_sdl2/CMakeLists.txt) and found where it installs.

set(_fried_vita_sdl2_dir "${CMAKE_CURRENT_LIST_DIR}/vita_sdl2")

if(DEFINED ENV{XDG_CACHE_HOME})
    set(_fried_default_deps_cache "$ENV{XDG_CACHE_HOME}/fried-engine/deps")
else()
    set(_fried_default_deps_cache "$ENV{HOME}/.cache/fried-engine/deps")
endif()
set(FRIED_DEPS_CACHE "${_fried_default_deps_cache}" CACHE PATH
    "Where the dependencies are unpacked and installed once for every build tree; empty keeps them in each build tree")

# Named after everything that changes what gets built, so a folder is never reused for a build it does not match.
function(_fried_vita_sdl2_prefix out_prefix)
    file(SHA256 "${_fried_vita_sdl2_dir}/CMakeLists.txt" _recipe_hash)
    file(SHA256 "${_fried_vita_sdl2_dir}/sdl2-pib.patch" _patch_hash)
    string(SHA256 _identity_hash "${_recipe_hash};${_patch_hash};${CMAKE_C_COMPILER_VERSION};${CMAKE_BUILD_TYPE}")
    string(SUBSTRING "${_identity_hash}" 0 16 _short_hash)
    if(FRIED_DEPS_CACHE)
        set(_root "${FRIED_DEPS_CACHE}/installed")
    else()
        set(_root "${CMAKE_BINARY_DIR}/_deps/installed")
    endif()
    set(${out_prefix} "${_root}/vita-${_short_hash}" PARENT_SCOPE)
endfunction()

function(_fried_install_vita_sdl2 prefix)
    set(_build_dir "${prefix}.build")
    file(REMOVE_RECURSE "${prefix}" "${_build_dir}")

    set(_configure_args
        -S "${_fried_vita_sdl2_dir}" -B "${_build_dir}"
        -G "${CMAKE_GENERATOR}"
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DCMAKE_INSTALL_PREFIX=${prefix}
        -DFRIED_SOURCES_CACHE=${FRIED_DEPS_CACHE}
    )
    message(STATUS "Building SDL2 for the Vita once into ${prefix}")
    foreach(_step IN ITEMS "" "--build;${_build_dir};--parallel" "--install;${_build_dir}")
        if(_step STREQUAL "")
            execute_process(COMMAND ${CMAKE_COMMAND} ${_configure_args} RESULT_VARIABLE _result)
        else()
            execute_process(COMMAND ${CMAKE_COMMAND} ${_step} RESULT_VARIABLE _result)
        endif()
        if(NOT _result EQUAL 0)
            message(FATAL_ERROR "Building SDL2 for the Vita failed")
        endif()
    endforeach()
    file(REMOVE_RECURSE "${_build_dir}")
    file(TOUCH "${prefix}/.fried-installed")
endfunction()

# Finds SDL2 where it installs, building it first if it is not there.
macro(fried_add_vita_sdl2)
    _fried_vita_sdl2_prefix(_prefix)
    file(MAKE_DIRECTORY "${_prefix}/..")
    file(LOCK "${_prefix}.lock" GUARD FILE TIMEOUT 3600)
    if(NOT EXISTS "${_prefix}/.fried-installed")
        _fried_install_vita_sdl2("${_prefix}")
    endif()

    file(GLOB_RECURSE _sdl2_config "${_prefix}/SDL2Config.cmake")
    list(GET _sdl2_config 0 _sdl2_config)
    get_filename_component(_sdl2_config_dir "${_sdl2_config}" DIRECTORY)
    set(SDL2_DIR "${_sdl2_config_dir}" CACHE PATH "" FORCE)
    find_package(SDL2 REQUIRED CONFIG NO_DEFAULT_PATH PATHS "${_sdl2_config_dir}")
endmacro()
