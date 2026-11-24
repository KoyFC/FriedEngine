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

    string(JSON _type ERROR_VARIABLE _error TYPE "${json}" ${platform} precision)
    if(NOT _error)
        if(NOT _type STREQUAL "STRING")
            message(FATAL_ERROR "project.fried declares \"${platform}.precision\" as something other than a string. Use \"single\" or \"double\".")
        endif()
        string(JSON _precision GET "${json}" ${platform} precision)
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
