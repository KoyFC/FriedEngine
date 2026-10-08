// Force-included into every hxcpp source on the fx-CG50. fxlibc is not a
// POSIX libc: these are the declarations hxcpp reaches for that it lacks,
// answered by runtime.cpp.

#pragma once

#include <limits.h>
#include <sys/types.h>
#include <time.h>

#ifndef PATH_MAX
#define PATH_MAX 256
#endif

#define WEXITSTATUS(status) (((status) >> 8) & 0xff)
#define WTERMSIG(status) ((status) & 0x7f)

#ifdef __cplusplus
extern "C" {
#endif

int nanosleep(const struct timespec *duration, struct timespec *remaining);

int setenv(const char *name, const char *value, int overwrite);
int unsetenv(const char *name);
char *realpath(const char *path, char *resolved);
ssize_t readlink(const char *path, char *buffer, size_t size);

#ifdef __cplusplus
}
#endif
