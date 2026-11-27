# What project.fried says about the size of a build, read from a platform's own
# section: "optimize" ("speed" or "size"), "lto" and, for pc, "compressExecutable".
#
# "speed" leaves the flags as they are, and "size" builds for size with unused
# functions and data dropped at link time. The DS is the one place the game's
# code keeps -O2 under "size": see Hxcpp.cmake on string literals.

# fried_read_project_flag(<json> <platform> <key> <out_value> <default>)
function(fried_read_project_flag json platform key out_value default)
    string(JSON _type ERROR_VARIABLE _error TYPE "${json}" ${platform} ${key})
    if(_error)
        set(${out_value} ${default} PARENT_SCOPE)
        return()
    endif()
    string(JSON _value GET "${json}" ${platform} ${key})
    set(${out_value} "${_value}" PARENT_SCOPE)
endfunction()

# fried_apply_project_optimize(<target> <json> <platform> <editor_player>)
function(fried_apply_project_optimize target_name json platform editor_player)
    if(editor_player)
        return()
    endif()

    fried_read_project_flag("${json}" ${platform} optimize _optimize speed)
    if(NOT _optimize STREQUAL "speed" AND NOT _optimize STREQUAL "size")
        message(FATAL_ERROR "project.fried declares \"${platform}.optimize\" as \"${_optimize}\", which is not one of: speed, size.")
    endif()
    fried_read_project_flag("${json}" ${platform} lto _lto OFF)
    if(NOT _lto STREQUAL "ON" AND NOT _lto STREQUAL "OFF" AND NOT _lto STREQUAL "true" AND NOT _lto STREQUAL "false")
        message(FATAL_ERROR "project.fried declares \"${platform}.lto\" as something other than true or false.")
    endif()

    set(_sections FALSE)
    if(NOT MSVC)
        if(_optimize STREQUAL "size")
            set(_sections TRUE)
            target_compile_options(fried_engine PRIVATE $<$<NOT:$<CONFIG:Debug>>:-Os>)
            if(NOT NINTENDO_DS)
                target_compile_options(${target_name} PRIVATE $<$<NOT:$<CONFIG:Debug>>:-Os>)
            endif()
        elseif(platform STREQUAL "pc")
            set(_sections TRUE)
        endif()
    endif()
    if(_sections)
        target_compile_options(fried_engine PRIVATE -ffunction-sections -fdata-sections)
        target_compile_options(${target_name} PRIVATE -ffunction-sections -fdata-sections)
        target_link_options(${target_name} PRIVATE "LINKER:--gc-sections")
        if(platform STREQUAL "pc")
            target_link_options(${target_name} PRIVATE $<$<CONFIG:Release,MinSizeRel>:-s>)
        endif()
    endif()

    if(_lto STREQUAL "ON" OR _lto STREQUAL "true")
        include(CheckIPOSupported)
        check_ipo_supported(RESULT _ipo OUTPUT _ipo_log LANGUAGES CXX)
        if(_ipo)
            set_target_properties(fried_engine ${target_name} PROPERTIES INTERPROCEDURAL_OPTIMIZATION_RELEASE ON INTERPROCEDURAL_OPTIMIZATION_MINSIZEREL ON)
        else()
            message(WARNING "project.fried asks for ${platform}.lto, and this toolchain does not support it: ${_ipo_log}")
        endif()
    endif()

    if(platform STREQUAL "pc")
        fried_read_project_flag("${json}" pc compressExecutable _compress OFF)
        if(_compress STREQUAL "ON" OR _compress STREQUAL "true")
            find_program(FRIED_UPX upx)
            if(FRIED_UPX)
                add_custom_command(TARGET ${target_name} POST_BUILD
                    COMMAND ${FRIED_UPX} --best --lzma -q $<TARGET_FILE:${target_name}>
                    COMMENT "Compressing the executable with UPX"
                    VERBATIM
                )
            else()
                message(WARNING "project.fried asks for pc.compressExecutable, and upx is not installed, so the executable is left as it is.")
            endif()
        endif()
    endif()
endfunction()

# fried_precompress_web(<target>)
#
# A .gz of the page's files, and a .br where brotli is installed, for a server
# that sends them with Content-Encoding. The plain files stay.
function(fried_precompress_web target_name)
    find_program(FRIED_GZIP gzip)
    find_program(FRIED_BROTLI brotli)
    foreach(_extension wasm data js)
        set(_file $<TARGET_FILE_DIR:${target_name}>/$<TARGET_FILE_BASE_NAME:${target_name}>.${_extension})
        if(FRIED_GZIP)
            add_custom_command(TARGET ${target_name} POST_BUILD
                COMMAND ${FRIED_GZIP} -9 -k -f ${_file}
                VERBATIM
            )
        endif()
        if(FRIED_BROTLI)
            add_custom_command(TARGET ${target_name} POST_BUILD
                COMMAND ${FRIED_BROTLI} -f -k ${_file}
                VERBATIM
            )
        endif()
    endforeach()
endfunction()
