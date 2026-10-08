// fxlibc has one locale, so hxcpp's Date formatting runs in it unchanged.

#pragma once

typedef void *locale_t;

#define LC_GLOBAL_LOCALE ((locale_t)-1)
#define LC_TIME_MASK 0

#ifdef __cplusplus
extern "C" {
#endif

locale_t newlocale(int mask, const char *name, locale_t base);
locale_t uselocale(locale_t locale);
void freelocale(locale_t locale);

#ifdef __cplusplus
}
#endif
