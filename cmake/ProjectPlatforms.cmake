include("${CMAKE_CURRENT_LIST_DIR}/AudioFiles.cmake")

# The names fried_add_game gives the platform it configures for. "pc" is every
# computer: Linux, Windows and macOS.
set(FRIED_PLATFORMS pc vita switch 3ds nds cg50 web)

# The most pixels a side a texture has on the 3DS and the DS, whose GPUs halve
# a larger image until it fits.
set(FRIED_GPU_MAX_TEXTURE_SIDE 1024)

# fried_read_project_platforms(<json> <out_list>)
#
# The platforms a project declares with its top-level "platforms", or an empty
# list when it declares none, which means every platform is allowed.
function(fried_read_project_platforms json out_list)
    string(JSON _type ERROR_VARIABLE _error TYPE "${json}" platforms)
    if(_error)
        set(${out_list} "" PARENT_SCOPE)
        return()
    endif()

    list(JOIN FRIED_PLATFORMS ", " _platform_list)
    if(NOT _type STREQUAL "ARRAY")
        message(FATAL_ERROR "project.fried declares \"platforms\" as something other than a list of names. Use a list of: ${_platform_list}.")
    endif()

    string(JSON _count LENGTH "${json}" platforms)
    if(_count EQUAL 0)
        message(FATAL_ERROR "project.fried declares an empty \"platforms\", which no platform could build. Name at least one of: ${_platform_list}, or remove the key to allow every platform.")
    endif()

    set(_declared "")
    math(EXPR _last "${_count} - 1")
    foreach(_index RANGE ${_last})
        string(JSON _name GET "${json}" platforms ${_index})
        if(NOT _name IN_LIST FRIED_PLATFORMS)
            message(FATAL_ERROR "project.fried declares the platform \"${_name}\", which is not one of: ${_platform_list}.")
        endif()
        list(APPEND _declared ${_name})
    endforeach()

    list(REMOVE_DUPLICATES _declared)
    set(${out_list} "${_declared}" PARENT_SCOPE)
endfunction()

# fried_require_declared_platform(<platform> <declared>)
#
# Refuses to configure for a platform the project does not declare. An empty
# list is a project that declares none, which builds for every platform.
function(fried_require_declared_platform platform declared)
    if(NOT declared)
        return()
    endif()
    if(NOT platform IN_LIST declared)
        list(JOIN declared ", " _declared_list)
        message(FATAL_ERROR "project.fried declares the platforms \"${_declared_list}\", so it does not build for ${platform}. Add \"${platform}\" to \"platforms\" to build it.")
    endif()
endfunction()

# fried_warn_oversized_images(<source_dir> <max_side> <platforms_label>)
#
# A texture past what the named platforms' GPUs take is halved until it fits,
# which is only seen once the game runs; this says so at configure time
# instead. Only PNGs are read, since their size sits at a fixed offset in the
# header.
function(fried_warn_oversized_images source_dir max_side platforms_label)
    file(GLOB_RECURSE _images CONFIGURE_DEPENDS "${source_dir}/*.png")
    foreach(_image ${_images})
        file(READ "${_image}" _header OFFSET 0 LIMIT 24 HEX)
        if(NOT _header MATCHES "^89504e470d0a1a0a")
            continue()
        endif()
        string(SUBSTRING "${_header}" 32 8 _width_hex)
        string(SUBSTRING "${_header}" 40 8 _height_hex)
        math(EXPR _width "0x${_width_hex}")
        math(EXPR _height "0x${_height_hex}")
        if(_width GREATER max_side OR _height GREATER max_side)
            file(RELATIVE_PATH _relative "${source_dir}" "${_image}")
            message(WARNING "${_relative} is ${_width}x${_height}, more than the ${max_side} pixels a side ${platforms_label} can take, so it will be drawn from a downscaled copy.")
        endif()
    endforeach()
endfunction()

# fried_warn_dropped_cg50_audio(<game_assets>)
#
# The calculator cannot play audio, so its build leaves the game's audio files
# out of the assets it copies.
function(fried_warn_dropped_cg50_audio game_assets)
    file(GLOB_RECURSE _files CONFIGURE_DEPENDS "${game_assets}/*")
    set(_count 0)
    foreach(_file ${_files})
        if(_file MATCHES "${FRIED_AUDIO_FILE_REGEX}")
            math(EXPR _count "${_count} + 1")
        endif()
    endforeach()
    if(_count GREATER 0)
        message(WARNING "The fx-CG50 plays no audio, so its build leaves out the ${_count} audio file(s) under ${game_assets}.")
    endif()
endfunction()

# fried_check_declared_platforms(<declared> <platform> <engine_assets> <game_assets>)
#
# What the platforms a project builds for ask of its assets, checked on every
# build, so a limit is met on the computer a game is developed on rather than
# on the hardware. A project declaring none is checked for the platform it is
# configured for.
function(fried_check_declared_platforms declared platform engine_assets game_assets)
    set(_checked ${declared})
    if(NOT _checked)
        set(_checked ${platform})
    endif()

    set(_gpu_platforms "")
    if(3ds IN_LIST _checked)
        list(APPEND _gpu_platforms "the 3DS")
    endif()
    if(nds IN_LIST _checked)
        list(APPEND _gpu_platforms "the DS")
    endif()
    if(_gpu_platforms)
        list(JOIN _gpu_platforms " and " _label)
        fried_warn_oversized_images("${engine_assets}" ${FRIED_GPU_MAX_TEXTURE_SIDE} "${_label}")
        fried_warn_oversized_images("${game_assets}" ${FRIED_GPU_MAX_TEXTURE_SIDE} "${_label}")
    endif()

    if(cg50 IN_LIST _checked)
        fried_warn_dropped_cg50_audio("${game_assets}")
    endif()
endfunction()
