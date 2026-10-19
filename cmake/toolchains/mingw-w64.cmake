set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(_mingw_triplet x86_64-w64-mingw32)

set(CMAKE_C_COMPILER ${_mingw_triplet}-gcc)
set(CMAKE_CXX_COMPILER ${_mingw_triplet}-g++)
set(CMAKE_RC_COMPILER ${_mingw_triplet}-windres)

# Fedora nests the MinGW sysroot one level deeper than Debian and Arch do.
if(EXISTS /usr/${_mingw_triplet}/sys-root/mingw)
    set(_mingw_default_sysroot /usr/${_mingw_triplet}/sys-root/mingw)
else()
    set(_mingw_default_sysroot /usr/${_mingw_triplet})
endif()
set(FRIED_MINGW_SYSROOT ${_mingw_default_sysroot} CACHE PATH "Root of the MinGW-w64 target libraries and headers")

set(CMAKE_FIND_ROOT_PATH ${FRIED_MINGW_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
