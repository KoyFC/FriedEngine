// Force-included into hxcpp's std sources on the consoles, which both run on
// newlib. They reach for PATH_MAX and the wait status macros without including
// anything that defines them there, which glibc's own headers happen to pull in
// for them.

#pragma once

#include <limits.h>
#include <sys/types.h>
#include <sys/wait.h>

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

// devkitA64 does not declare readlink() at all, which makes the one call hxcpp
// makes to it a compile error rather than a link error. Declaring it here is
// what posix_extras.cpp then answers.
extern "C" ssize_t readlink(const char *path, char *buffer, size_t size);
