# The box2d backend of the physics2d module (modules.json): Box2D 3, plain C
# under the MIT license, built from its sources here instead of through its
# own CMake project, which turns on verbose makefiles for the whole build and
# builds samples. The stub is what a platform links when it does not use the
# backend but the game's code still refers to it.

set(FRIED_BOX2D_VERSION 3.1.1)
set(FRIED_BOX2D_SHA256 fb6ef914b50f4312d7d921a600eabc12318bb3c55a0b8c0b90608fa4488ef2e4)
get_filename_component(_fried_box2d_engine_dir "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

# Where the sources are unpacked: once for every build tree if there is a cache, like the PC dependencies.
function(_fried_box2d_sources out_directory)
    if(FRIED_DEPS_CACHE)
        set(_root "${FRIED_DEPS_CACHE}")
    elseif(DEFINED ENV{XDG_CACHE_HOME})
        set(_root "$ENV{XDG_CACHE_HOME}/fried-engine/deps")
    elseif(CMAKE_HOST_WIN32)
        set(_root "$ENV{LOCALAPPDATA}/fried-engine/deps")
    else()
        set(_root "$ENV{HOME}/.cache/fried-engine/deps")
    endif()
    set(_source "${_root}/box2d-${FRIED_BOX2D_VERSION}")

    if(NOT EXISTS "${_source}/include/box2d/box2d.h")
        set(_archive "${_root}/box2d-${FRIED_BOX2D_VERSION}.tar.gz")
        message(STATUS "Downloading Box2D ${FRIED_BOX2D_VERSION}")
        file(DOWNLOAD "https://github.com/erincatto/box2d/archive/refs/tags/v${FRIED_BOX2D_VERSION}.tar.gz" "${_archive}"
            EXPECTED_HASH SHA256=${FRIED_BOX2D_SHA256}
            STATUS _status
        )
        list(GET _status 0 _code)
        if(NOT _code EQUAL 0)
            file(REMOVE "${_archive}")
            message(FATAL_ERROR "Box2D ${FRIED_BOX2D_VERSION} could not be downloaded: ${_status}")
        endif()
        file(REMOVE_RECURSE "${_root}/box2d-unpack")
        file(ARCHIVE_EXTRACT INPUT "${_archive}" DESTINATION "${_root}/box2d-unpack")
        file(REMOVE_RECURSE "${_source}")
        file(RENAME "${_root}/box2d-unpack/box2d-${FRIED_BOX2D_VERSION}" "${_source}")
        file(REMOVE_RECURSE "${_root}/box2d-unpack")
    endif()
    set(${out_directory} "${_source}" PARENT_SCOPE)
endfunction()

# fried_link_module_box2d(<target>)
function(fried_link_module_box2d target_name)
    if(NOT TARGET fried_box2d)
        # The sandbox and a game may declare only C++, and Box2D is C.
        enable_language(C)
        _fried_box2d_sources(_source)
        file(GLOB _box2d_files "${_source}/src/*.c")
        add_library(fried_box2d STATIC ${_box2d_files})
        target_include_directories(fried_box2d PUBLIC "${_source}/include" PRIVATE "${_source}/src")
        set_target_properties(fried_box2d PROPERTIES C_STANDARD 17 C_STANDARD_REQUIRED ON C_EXTENSIONS ON C_VISIBILITY_PRESET hidden POSITION_INDEPENDENT_CODE ON)
        if(NOT MSVC)
            # Box2D's results are the same on every machine only without fused multiply-adds.
            target_compile_options(fried_box2d PRIVATE -ffp-contract=off -w)
        endif()
        # The 3DS and the Vita have no NEON the code can count on, and the browser needs a flag for WebAssembly SIMD.
        if(NINTENDO_3DS OR VITA OR FRIED_WEB)
            target_compile_definitions(fried_box2d PRIVATE BOX2D_DISABLE_SIMD)
        endif()
    endif()
    target_sources(${target_name} PRIVATE "${_fried_box2d_engine_dir}/native/modules/box2d/box2d_world.cpp")
    target_link_libraries(${target_name} PRIVATE fried_box2d)
endfunction()

# fried_link_module_box2d_stub(<target>)
function(fried_link_module_box2d_stub target_name)
    target_sources(${target_name} PRIVATE "${_fried_box2d_engine_dir}/native/modules/box2d/box2d_stub.cpp")
endfunction()
