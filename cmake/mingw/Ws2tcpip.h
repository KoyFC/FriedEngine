// hxcpp's Socket.cpp spells this header as the Windows SDK does, and MinGW-w64
// ships it in lower case, which a case-sensitive host does not resolve.

#pragma once

#include_next <ws2tcpip.h>
