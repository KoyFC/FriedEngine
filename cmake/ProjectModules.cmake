file(READ "${FRIED_MODULES_MANIFEST}" FRIED_MODULES_JSON)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${FRIED_MODULES_MANIFEST}")

# What project.fried chooses for the engine's modules. fried_import resolves
# every platform's profile against modules.json and refuses a backend that does
# not run on its platform, so what is read here is already valid: a "modules"
# map in each profile naming the backend of every module.

# fried_profile_backend(<json> <platform> <module> <out_backend>)
function(fried_profile_backend json platform module out_backend)
    string(JSON _backend ERROR_VARIABLE _error GET "${json}" platforms ${platform} modules ${module})
    if(_error)
        string(JSON _manifest_default GET "${FRIED_MODULES_JSON}" ${module} default)
        set(_backend ${_manifest_default})
    endif()
    set(${out_backend} ${_backend} PARENT_SCOPE)
endfunction()

# fried_warn_degraded_modules(<json> <platform>)
#
# A backend that runs on the platform without doing everything says so once per
# configure, with the text modules.json gives it.
function(fried_warn_degraded_modules json platform)
    string(JSON _count LENGTH "${FRIED_MODULES_JSON}")
    math(EXPR _last "${_count} - 1")
    foreach(_index RANGE ${_last})
        string(JSON _module MEMBER "${FRIED_MODULES_JSON}" ${_index})
        fried_profile_backend("${json}" ${platform} ${_module} _backend)
        string(JSON _note ERROR_VARIABLE _error GET "${FRIED_MODULES_JSON}" ${_module} backends ${_backend} degraded ${platform})
        if(NOT _error)
            message(WARNING "${_note}")
        endif()
    endforeach()
endfunction()

# fried_link_profile_modules(<target> <json> <platform> <editor_player>)
#
# Links the native part of every backend some profile of the project uses: the
# real one where this platform uses it, the stub of it everywhere else, since
# the game's code is the same for all platforms and refers to the backend
# wherever it is used. The editor's player is a computer build that links every
# real backend a computer runs, so what a scene holds can be edited and shown.
# The backend each module has on this platform is written for the importer.
function(fried_link_profile_modules target_name json platform editor_player)
    set(_used "")
    string(JSON _platform_count LENGTH "${json}" platforms)
    math(EXPR _last_platform "${_platform_count} - 1")
    foreach(_platform_index RANGE ${_last_platform})
        string(JSON _declared MEMBER "${json}" platforms ${_platform_index})
        string(JSON _module_count LENGTH "${FRIED_MODULES_JSON}")
        math(EXPR _last_module "${_module_count} - 1")
        foreach(_module_index RANGE ${_last_module})
            string(JSON _module MEMBER "${FRIED_MODULES_JSON}" ${_module_index})
            fried_profile_backend("${json}" ${_declared} ${_module} _backend)
            list(APPEND _used "${_module}=${_backend}")
        endforeach()
    endforeach()
    if(editor_player)
        # The editor plays as any platform, so it holds the code of every backend and links each one's native part.
        string(JSON _module_count LENGTH "${FRIED_MODULES_JSON}")
        math(EXPR _last_module "${_module_count} - 1")
        foreach(_module_index RANGE ${_last_module})
            string(JSON _module MEMBER "${FRIED_MODULES_JSON}" ${_module_index})
            string(JSON _backend_count LENGTH "${FRIED_MODULES_JSON}" ${_module} backends)
            math(EXPR _last_backend "${_backend_count} - 1")
            foreach(_backend_index RANGE ${_last_backend})
                string(JSON _backend MEMBER "${FRIED_MODULES_JSON}" ${_module} backends ${_backend_index})
                list(APPEND _used "${_module}=${_backend}")
            endforeach()
        endforeach()
    endif()
    list(REMOVE_DUPLICATES _used)

    set(_active_json "")
    string(JSON _module_count LENGTH "${FRIED_MODULES_JSON}")
    math(EXPR _last_module "${_module_count} - 1")
    foreach(_module_index RANGE ${_last_module})
        string(JSON _module MEMBER "${FRIED_MODULES_JSON}" ${_module_index})
        fried_profile_backend("${json}" ${platform} ${_module} _backend)
        string(APPEND _active_json "${_active_json_separator}\"${_module}\": \"${_backend}\"")
        set(_active_json_separator ", ")
    endforeach()
    file(WRITE ${CMAKE_BINARY_DIR}/modules.json.tmp "{\"platform\": \"${platform}\", \"active\": {${_active_json}}}\n")
    execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_BINARY_DIR}/modules.json.tmp ${CMAKE_BINARY_DIR}/modules.json)

    foreach(_choice ${_used})
        string(REPLACE "=" ";" _parts "${_choice}")
        list(GET _parts 0 _module)
        list(GET _parts 1 _backend)
        string(JSON _native ERROR_VARIABLE _error GET "${FRIED_MODULES_JSON}" ${_module} backends ${_backend} native)
        if(_error)
            continue()
        endif()

        fried_profile_backend("${json}" ${platform} ${_module} _here)
        if(_backend STREQUAL _here OR editor_player)
            set(_link fried_link_module_${_native})
        else()
            set(_link fried_link_module_${_native}_stub)
        endif()
        if(NOT COMMAND ${_link})
            message(FATAL_ERROR "The module ${_module} uses ${_backend}, and the engine has no ${_link} to build it.")
        endif()
        cmake_language(CALL ${_link} ${target_name})
    endforeach()
endfunction()
