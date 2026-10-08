// fxlibc has no wide characters. hxcpp includes this everywhere and calls
// these three from its UTF-16 string paths.

#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

size_t wcslen(const wchar_t *string);
long wcstol(const wchar_t *string, wchar_t **end, int base);
double wcstod(const wchar_t *string, wchar_t **end);

#ifdef __cplusplus
}
#endif
