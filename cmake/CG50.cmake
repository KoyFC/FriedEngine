# Builds for the Casio fx-CG50 on gint, with the fxSDK's toolchain file:
#
#   cmake -S . -B build/cg50 \
#       -DCMAKE_TOOLCHAIN_FILE=$(fxsdk path sysroot)/../../../lib/cmake/fxsdk/FXCG50.cmake
#
# FRIED_CG50, which every fx-CG50 branch in this repository keys off, is set by
# FriedEngine.cmake from the toolchain's own FXSDK_PLATFORM_LONG, and C++ sees
# the toolchain's TARGET_FXCG50. Exceptions need the libstdc++ from
# packaging/cg50/, since the fxSDK's own is built without them.

# The fxSDK's modules (FindGint, GenerateG3A) sit next to its toolchain file.
get_filename_component(_fried_fxsdk_module_dir "${CMAKE_TOOLCHAIN_FILE}" DIRECTORY)
list(APPEND CMAKE_MODULE_PATH "${_fried_fxsdk_module_dir}")

include(GenerateG3A)
find_package(Gint 2.9 REQUIRED)

set(_fried_gint_dir "${CMAKE_CURRENT_LIST_DIR}/gint")
set(_fried_cg50_generated_dir "${CMAKE_BINARY_DIR}/fried_cg50")

# The toolchain compiles everything -ffreestanding, which in C++ also makes
# libstdc++ freestanding: no std::string, no operator new, none of the
# helpers a throw needs. C keeps it, as gint itself is built.
function(fried_cg50_keep_freestanding_to_c)
    get_directory_property(_options COMPILE_OPTIONS)
    list(TRANSFORM _options REPLACE "^-ffreestanding$" "$<$<COMPILE_LANGUAGE:C>:-ffreestanding>")
    set_directory_properties(PROPERTIES COMPILE_OPTIONS "${_options}")
endfunction()

fried_cg50_keep_freestanding_to_c()

# A .g3a holds at most 2 MB of code and data. Unoptimized, the engine alone
# outgrows that, and -O3 makes it over a quarter larger than -Os, so every
# configuration optimizes for size; this comes after the configuration's own
# flags, so it is the -O that applies.
add_compile_options(-Os)

# Rewrites only when the contents change, so configuring again does not make
# everything that includes the file rebuild.
function(_fried_cg50_write_if_changed path contents)
    file(WRITE "${path}.tmp" "${contents}")
    configure_file("${path}.tmp" "${path}" COPYONLY)
    file(REMOVE "${path}.tmp")
endfunction()

# _fried_cg50_patch(<contents_var> <file> <from> <to>)
#
# One replacement per call: a list of them would split on every semicolon in
# the C++. Fails loudly when it finds nothing, which is what a new hxcpp
# release changing these lines would look like.
function(_fried_cg50_patch contents_var file from to)
    string(FIND "${${contents_var}}" "${from}" _found)
    if(_found EQUAL -1)
        message(FATAL_ERROR "${file} no longer contains \"${from}\", which the fx-CG50 build patches. cmake/CG50.cmake was written against hxcpp 4.3.2 and gint 2.11.")
    endif()
    string(REPLACE "${from}" "${to}" _contents "${${contents_var}}")
    set(${contents_var} "${_contents}" PARENT_SCOPE)
endfunction()

# fried_cg50_patch_hxcpp(<runtime_sources_var> <include_dir_var>)
#
# hxcpp assumes a few things the calculator does not give it. These copies of
# its sources, written into the build tree, are what the fx-CG50 compiles in
# their place; the haxelib itself is never touched.
function(fried_cg50_patch_hxcpp runtime_sources_var include_dir_var)
    set(_runtime_sources ${${runtime_sources_var}})
    set(_patched_dir "${_fried_cg50_generated_dir}/hxcpp")

    # Immix reserves its blocks 32 at a time, a 1 MB allocation no gint heap
    # arena can satisfy; 4 at a time is 128 KB. And even a single threaded app
    # gets helper threads to mark and reclaim with, which gint cannot start.
    file(READ "${HXCPP_ROOT}/src/hx/gc/Immix.cpp" _immix)
    _fried_cg50_patch(_immix "hxcpp's src/hx/gc/Immix.cpp"
        "#define IMMIX_BLOCK_GROUP_BITS  5"
        "#define IMMIX_BLOCK_GROUP_BITS  2"
    )
    _fried_cg50_patch(_immix "hxcpp's src/hx/gc/Immix.cpp"
        "#if HX_HAS_ATOMIC && (HXCPP_GC_DEBUG_LEVEL==0)"
        "#if !defined(HXCPP_SINGLE_THREADED_APP) && HX_HAS_ATOMIC && (HXCPP_GC_DEBUG_LEVEL==0)"
    )
    _fried_cg50_write_if_changed("${_patched_dir}/src/hx/gc/Immix.cpp" "${_immix}")

    # The main thread's info goes in a thread_local, which the SH4 reaches
    # through a thread pointer (GBR) that gint never sets up.
    file(READ "${HXCPP_ROOT}/src/hx/Thread.cpp" _thread)
    _fried_cg50_patch(_thread "hxcpp's src/hx/Thread.cpp"
        "   #define HXCPP_THREAD_INFO_LOCAL"
        "   #define HXCPP_THREAD_INFO_SINGLETON"
    )
    _fried_cg50_write_if_changed("${_patched_dir}/src/hx/Thread.cpp" "${_thread}")

    # The SH4 faults on a misaligned 32-bit access, which x86 and ARM let
    # pass. A string's hash is kept right after its terminating zero,
    # wherever that falls, and read and written there as an unsigned int.
    file(READ "${HXCPP_ROOT}/src/String.cpp" _string)
    _fried_cg50_patch(_string "hxcpp's src/String.cpp"
        "*((unsigned int *)(result + len + 1)) = hash;"
        "memcpy(result + len + 1, &hash, sizeof(hash));"
    )
    _fried_cg50_patch(_string "hxcpp's src/String.cpp"
        "*((unsigned int *)(str+char16Count+1) ) = hash;"
        "memcpy(str+char16Count+1, &hash, sizeof(hash));"
    )
    _fried_cg50_write_if_changed("${_patched_dir}/src/String.cpp" "${_string}")

    # hxcpp.h includes hxString.h by a quoted name, which always finds the
    # copy next to it, so the patched one needs the rest of include/ beside it.
    file(COPY "${HXCPP_ROOT}/include/" DESTINATION "${_patched_dir}/include" PATTERN "hxString.h" EXCLUDE)
    file(READ "${HXCPP_ROOT}/include/hxString.h" _hx_string)
    _fried_cg50_patch(_hx_string "hxcpp's include/hxString.h"
        "*((unsigned int *)(__s+length+1) )"
        "[&] { unsigned int hash; memcpy(&hash, __s + length + 1, sizeof(hash)); return hash; }()"
    )
    _fried_cg50_write_if_changed("${_patched_dir}/include/hxString.h" "${_hx_string}")

    # The copies still include their neighbours by relative paths.
    foreach(_source src/hx/gc/Immix.cpp src/hx/Thread.cpp src/String.cpp)
        list(REMOVE_ITEM _runtime_sources "${HXCPP_ROOT}/${_source}")
        list(APPEND _runtime_sources "${_patched_dir}/${_source}")
        set_source_files_properties("${_patched_dir}/${_source}" PROPERTIES
            INCLUDE_DIRECTORIES "${HXCPP_ROOT}/src;${HXCPP_ROOT}/src/hx/gc"
        )
    endforeach()

    set(${runtime_sources_var} ${_runtime_sources} PARENT_SCOPE)
    set(${include_dir_var} "${_patched_dir}/include" PARENT_SCOPE)
endfunction()

# The linker scripts gint links with throw away the unwind tables, as gint
# itself has no exceptions. These are the same scripts keeping them, after the
# rest of the read-only data, with a symbol runtime.cpp registers them from.
# gint picks one of two by configuration, as FindGint does here.
function(_fried_cg50_write_linker_scripts out_var)
    set(_scripts "")
    foreach(_name fxcg50_fastload.ld fxcg50.ld)
        execute_process(
            COMMAND ${CMAKE_C_COMPILER} -print-file-name=${_name}
            OUTPUT_VARIABLE _gint_script
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        file(READ "${_gint_script}" _script)
        _fried_cg50_patch(_script "gint's ${_name}"
            "\t\t*(.rodata .rodata.*)\n\t} > rom"
            "\t\t*(.rodata .rodata.*)\n\n\t\t*(.gcc_except_table .gcc_except_table.*)\n\n\t\t. = ALIGN(4);\n\t\t_eh_frame_start = . ;\n\t\tKEEP(*(.eh_frame))\n\t\tLONG(0)\n\t} > rom"
        )
        _fried_cg50_patch(_script "gint's ${_name}"
            "\t\t*(.eh_frame)\n"
            ""
        )
        _fried_cg50_write_if_changed("${_fried_cg50_generated_dir}/${_name}" "${_script}")
        list(APPEND _scripts "${_fried_cg50_generated_dir}/${_name}")
    endforeach()
    set(${out_var} ${_scripts} PARENT_SCOPE)
endfunction()

# fried_cg50_configure_hxcpp_target(<target>)
function(fried_cg50_configure_hxcpp_target target_name)
    target_sources(${target_name} PRIVATE "${_fried_gint_dir}/runtime.cpp")

    # cmake/gint/ only provides headers fxlibc does not have, so it can come
    # first without hiding any of fxlibc's.
    target_include_directories(${target_name} SYSTEM BEFORE PRIVATE "${_fried_gint_dir}")
    target_compile_options(${target_name} PRIVATE
        "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-include ${_fried_gint_dir}/posix_extras.h>"
    )

    target_compile_definitions(${target_name} PRIVATE
        HXCPP_SINGLE_THREADED_APP
        HXCPP_ALIGN_ALLOC
    )

    _fried_cg50_write_linker_scripts(_linker_scripts)
    list(GET _linker_scripts 0 _fastload_script)
    list(GET _linker_scripts 1 _linker_script)
    set(_chosen_script "$<IF:$<CONFIG:FastLoad>,${_fastload_script},${_linker_script}>")
    set_target_properties(Gint::Gint PROPERTIES
        INTERFACE_LINK_OPTIONS "-T;${_chosen_script}"
        INTERFACE_LINK_DEPENDS "${_chosen_script}"
    )

    # Every file function that reaches the OS's filesystem is replaced by
    # os_filesystem.cpp, for whichever library calls it.
    target_sources(${target_name} PRIVATE "${_fried_gint_dir}/os_filesystem.cpp")

    target_link_libraries(${target_name} PRIVATE Gint::Gint stdc++ supc++ gcc)
endfunction()

# fried_add_cg50_g3a(<target> NAME ICON_UNSELECTED ICON_SELECTED ENGINE_ASSETS GAME_ASSETS)
#
# The assets do not go in the .g3a: they are staged next to it as the folder
# to copy to the root of the calculator's storage, named after the game,
# which is where native/platform/filesystem_gint.cpp looks for them. Audio is
# left out, since the calculator has nothing to play it on.
function(fried_add_cg50_g3a target_name)
    cmake_parse_arguments(G3A
        ""
        "NAME;ICON_UNSELECTED;ICON_SELECTED;ENGINE_ASSETS;GAME_ASSETS"
        ""
        ${ARGN}
    )

    # Passed none, the fxSDK leaves the menu icon blank.
    set(_icon_arguments "")
    if(EXISTS "${G3A_ICON_UNSELECTED}" AND EXISTS "${G3A_ICON_SELECTED}")
        set(_icon_arguments ICONS "${G3A_ICON_UNSELECTED}" "${G3A_ICON_SELECTED}")
    endif()

    generate_g3a(TARGET ${target_name}
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.g3a"
        NAME "${G3A_NAME}"
        ${_icon_arguments}
    )

    add_custom_target(${target_name}_assets ALL
        COMMAND ${CMAKE_COMMAND}
            "-DENGINE_ASSETS=${G3A_ENGINE_ASSETS}"
            "-DGAME_ASSETS=${G3A_GAME_ASSETS}"
            "-DDESTINATION=${CMAKE_CURRENT_BINARY_DIR}/${G3A_NAME}/assets"
            -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/CG50StageAssets.cmake"
        COMMENT "Staging the engine and game asset roots to copy next to the .g3a"
    )
endfunction()
