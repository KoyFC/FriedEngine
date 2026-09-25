// Force-included into hxcpp's std sources on Vita. They reach for PATH_MAX and
// the wait status macros without including anything that defines them on
// newlib, which glibc's own headers happen to pull in for them.

#pragma once

#include <limits.h>
#include <sys/wait.h>

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif
