# fried_read_project_display(<json> <platform> <out_mode> <out_width> <out_height>)
#
# Resolves the display a project declares for one platform: each key under
# "<platform>.display" overrides the same key under the top-level "display".
# Width and height are only required, and only returned, when the mode is not
# "default".
function(fried_read_project_display json platform out_mode out_width out_height)
    set(_modes default fit integer expand stretch)

    foreach(_key mode width height)
        string(JSON _value ERROR_VARIABLE _error GET "${json}" ${platform} display ${_key})
        if(_error)
            string(JSON _value ERROR_VARIABLE _error GET "${json}" display ${_key})
        endif()
        if(_error)
            set(_value "")
        endif()
        set(_${_key} "${_value}")
    endforeach()

    if(_mode STREQUAL "")
        set(_mode default)
    endif()
    if(NOT _mode IN_LIST _modes)
        list(JOIN _modes ", " _mode_list)
        message(FATAL_ERROR "project.fried declares the display mode \"${_mode}\" for ${platform}, which is not one of: ${_mode_list}.")
    endif()

    if(_mode STREQUAL "default")
        set(_width "")
        set(_height "")
    else()
        foreach(_key width height)
            if(NOT _${_key} MATCHES "^[1-9][0-9]*$")
                message(FATAL_ERROR "project.fried declares the display mode \"${_mode}\" for ${platform}, which needs \"display.${_key}\" as a whole number of pixels above zero.")
            endif()
        endforeach()
    endif()

    set(${out_mode} ${_mode} PARENT_SCOPE)
    set(${out_width} ${_width} PARENT_SCOPE)
    set(${out_height} ${_height} PARENT_SCOPE)
endfunction()
