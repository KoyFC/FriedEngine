// hxcpp's std sources include <xlocale.h> on every POSIX system that is not
// glibc. newlib has no such header: it declares newlocale()/uselocale() and
// LC_GLOBAL_LOCALE in <locale.h> itself.

#pragma once

#include <locale.h>
