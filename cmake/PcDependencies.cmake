option(FRIED_SYSTEM_SDL2 "Link the installed SDL2 libraries on PC instead of building them from source" OFF)

if(CMAKE_HOST_WIN32)
    set(_fried_default_deps_cache "$ENV{LOCALAPPDATA}/fried-engine/deps")
elseif(DEFINED ENV{XDG_CACHE_HOME})
    set(_fried_default_deps_cache "$ENV{XDG_CACHE_HOME}/fried-engine/deps")
else()
    set(_fried_default_deps_cache "$ENV{HOME}/.cache/fried-engine/deps")
endif()
file(TO_CMAKE_PATH "${_fried_default_deps_cache}" _fried_default_deps_cache)
set(FRIED_DEPS_CACHE "${_fried_default_deps_cache}" CACHE PATH
    "Where the PC dependencies are unpacked and installed once for every build tree; empty keeps them in each build tree")

set(_fried_pc_sdl2_dir "${CMAKE_CURRENT_LIST_DIR}/pc_sdl2")

# Where the installed libraries go: one folder per compiler and configuration, named after everything that changes what gets built, so a folder is never reused for a build it does not match.
function(_fried_pc_sdl2_prefix out_prefix)
    file(SHA256 "${_fried_pc_sdl2_dir}/CMakeLists.txt" _recipe_hash)
    set(_identity
        "${_recipe_hash}"
        "${CMAKE_SYSTEM_NAME}" "${CMAKE_SYSTEM_PROCESSOR}"
        "${CMAKE_C_COMPILER_ID}" "${CMAKE_C_COMPILER_VERSION}"
        "${CMAKE_CXX_COMPILER_ID}" "${CMAKE_CXX_COMPILER_VERSION}"
        "${CMAKE_C_FLAGS}" "${CMAKE_CXX_FLAGS}"
        "${CMAKE_MSVC_RUNTIME_LIBRARY}"
        "${CMAKE_GENERATOR_PLATFORM}" "${CMAKE_GENERATOR_TOOLSET}"
    )
    if(NOT CMAKE_CONFIGURATION_TYPES)
        list(APPEND _identity "${CMAKE_BUILD_TYPE}")
    endif()
    string(SHA256 _identity_hash "${_identity}")
    string(SUBSTRING "${_identity_hash}" 0 16 _short_hash)

    string(TOLOWER "${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}" _platform)
    if(FRIED_DEPS_CACHE)
        set(_root "${FRIED_DEPS_CACHE}/installed")
    else()
        set(_root "${CMAKE_BINARY_DIR}/_deps/installed")
    endif()
    set(${out_prefix} "${_root}/${_platform}-${_short_hash}" PARENT_SCOPE)
endfunction()

# Compiles the four libraries as a build of their own, and installs them into the prefix.
function(_fried_install_pc_sdl2 prefix)
    set(_build_dir "${prefix}.build")
    file(REMOVE_RECURSE "${prefix}" "${_build_dir}")

    set(_configure_args
        -S "${_fried_pc_sdl2_dir}" -B "${_build_dir}"
        -G "${CMAKE_GENERATOR}"
        -DCMAKE_INSTALL_PREFIX=${prefix}
        -DFRIED_SOURCES_CACHE=${FRIED_DEPS_CACHE}
    )
    foreach(_inherited
        CMAKE_TOOLCHAIN_FILE CMAKE_C_COMPILER CMAKE_CXX_COMPILER CMAKE_RC_COMPILER
        CMAKE_C_FLAGS CMAKE_CXX_FLAGS CMAKE_MSVC_RUNTIME_LIBRARY FRIED_MINGW_SYSROOT
        CMAKE_GENERATOR_PLATFORM CMAKE_GENERATOR_TOOLSET CMAKE_MAKE_PROGRAM
    )
        if(DEFINED ${_inherited} AND NOT "${${_inherited}}" STREQUAL "")
            list(APPEND _configure_args "-D${_inherited}=${${_inherited}}")
        endif()
    endforeach()

    if(CMAKE_CONFIGURATION_TYPES)
        set(_configs Debug Release)
    else()
        set(_configs ${CMAKE_BUILD_TYPE})
        list(APPEND _configure_args -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE})
    endif()

    message(STATUS "Building SDL2 and its companions once into ${prefix}")
    execute_process(COMMAND ${CMAKE_COMMAND} ${_configure_args} RESULT_VARIABLE _result)
    if(NOT _result EQUAL 0)
        message(FATAL_ERROR "Configuring SDL2 failed")
    endif()
    foreach(_config IN LISTS _configs)
        execute_process(COMMAND ${CMAKE_COMMAND} --build "${_build_dir}" --config ${_config} --parallel
            RESULT_VARIABLE _result)
        if(NOT _result EQUAL 0)
            message(FATAL_ERROR "Building SDL2 failed")
        endif()
        execute_process(COMMAND ${CMAKE_COMMAND} --install "${_build_dir}" --config ${_config}
            RESULT_VARIABLE _result)
        if(NOT _result EQUAL 0)
            message(FATAL_ERROR "Installing SDL2 failed")
        endif()
    endforeach()

    file(REMOVE_RECURSE "${_build_dir}")
    file(TOUCH "${prefix}/.fried-installed")
endfunction()

# The prefix lays its package configs out under lib, lib64 or the root, depending on the system, so each is looked up by name.
function(_fried_use_installed_package prefix name)
    file(GLOB_RECURSE _config "${prefix}/${name}Config.cmake")
    list(GET _config 0 _config)
    get_filename_component(_dir "${_config}" DIRECTORY)
    set(${name}_DIR "${_dir}" CACHE PATH "" FORCE)
    find_package(${name} REQUIRED CONFIG NO_DEFAULT_PATH PATHS "${_dir}")
endfunction()

function(fried_add_pc_sdl2 out_link_targets)
    if(FRIED_SYSTEM_SDL2)
        find_package(SDL2 REQUIRED CONFIG)
        find_package(SDL2_image REQUIRED CONFIG)
        find_package(SDL2_mixer REQUIRED CONFIG)
        find_package(SDL2_ttf REQUIRED CONFIG)

        set(${out_link_targets}
            SDL2::SDL2
            SDL2_image::SDL2_image
            SDL2_mixer::SDL2_mixer
            SDL2_ttf::SDL2_ttf
            PARENT_SCOPE
        )
        return()
    endif()

    _fried_pc_sdl2_prefix(_prefix)
    file(MAKE_DIRECTORY "${_prefix}/..")
    file(LOCK "${_prefix}.lock" GUARD FUNCTION TIMEOUT 3600)
    if(NOT EXISTS "${_prefix}/.fried-installed")
        _fried_install_pc_sdl2("${_prefix}")
    endif()

    foreach(_package SDL2 SDL2_image SDL2_mixer SDL2_ttf)
        _fried_use_installed_package("${_prefix}" ${_package})
    endforeach()

    # A fixed place for editors, wherever the libraries were installed.
    file(GLOB _installed_headers "${_prefix}/include/SDL2/*.h")
    file(COPY ${_installed_headers} DESTINATION "${CMAKE_BINARY_DIR}/_deps/sdl2-companion-headers")

    set(${out_link_targets}
        SDL2_image::SDL2_image-static
        SDL2_mixer::SDL2_mixer-static
        SDL2_ttf::SDL2_ttf-static
        SDL2::SDL2-static
        PARENT_SCOPE
    )
endfunction()
