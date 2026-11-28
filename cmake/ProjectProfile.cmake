# Everything a build reads from the profile of the platform it is for, which
# is "platforms.<platform>" in project.fried as fried_import writes it out.

# fried_profile_get(<json> <platform> <key> <out_value> <default>)
#
# A setting of the platform's profile, or the default when it does not give one.
function(fried_profile_get json platform key out_value default)
    string(JSON _type ERROR_VARIABLE _error TYPE "${json}" platforms ${platform} ${key})
    if(_error)
        set(${out_value} "${default}" PARENT_SCOPE)
        return()
    endif()
    string(JSON _value GET "${json}" platforms ${platform} ${key})
    set(${out_value} "${_value}" PARENT_SCOPE)
endfunction()

# fried_profile_text(<json> <fallback> <max_length> <out_variable> <platform> <key>)
#
# A line of packaging text a platform's profile may give, or the fallback when
# it does not. One too long for what the package holds is refused at configure
# time rather than cut where nobody can see it.
function(fried_profile_text json fallback max_length out_variable platform key)
    fried_profile_get("${json}" ${platform} ${key} _value "")
    if(_value STREQUAL "")
        set(_value "${fallback}")
    else()
        string(LENGTH "${_value}" _length)
        if(_length GREATER ${max_length})
            message(FATAL_ERROR "project.fried gives ${platform}.${key} ${_length} characters, and the package holds ${max_length}.")
        endif()
    endif()
    set(${out_variable} "${_value}" PARENT_SCOPE)
endfunction()

# fried_read_project_precision(<json> <platform> <out_float32>)
#
# Whether Haxe's Float is a 32-bit float in the build for the platform, from
# the "precision" of the platform's own section of project.fried: "single" is
# a 32-bit float and "double" a 64-bit double. A project that says nothing
# gets what the platform is best at: single on the DS, whose ARM9 has no
# floating point unit and does a double in software, and double everywhere
# else. FriedCore's defaultPrecision keeps the same table for the tools.
function(fried_read_project_precision json platform out_float32)
    if(platform STREQUAL "nds")
        set(_precision single)
    else()
        set(_precision double)
    endif()

    string(JSON _type ERROR_VARIABLE _error TYPE "${json}" platforms ${platform} precision)
    if(NOT _error)
        if(NOT _type STREQUAL "STRING")
            message(FATAL_ERROR "project.fried declares \"${platform}.precision\" as something other than a string. Use \"single\" or \"double\".")
        endif()
        string(JSON _precision GET "${json}" platforms ${platform} precision)
        if(NOT _precision STREQUAL "single" AND NOT _precision STREQUAL "double")
            message(FATAL_ERROR "project.fried declares the precision \"${_precision}\" for ${platform}, which is not one of: single, double.")
        endif()
        if(platform STREQUAL "cg50" AND _precision STREQUAL "single")
            message(FATAL_ERROR "project.fried declares the precision \"single\" for cg50, which has not been built that way. Use \"double\" or remove the key.")
        endif()
    endif()

    if(_precision STREQUAL "single")
        set(${out_float32} ON PARENT_SCOPE)
    else()
        set(${out_float32} OFF PARENT_SCOPE)
    endif()
endfunction()
