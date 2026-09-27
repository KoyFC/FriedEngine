#include <unistd.h>

// Neither console implements readlink(): the Vita declares it and links nothing,
// and devkitA64 does not even declare it. hxcpp calls it to read /proc/self/exe,
// a path neither console has either.
extern "C" ssize_t readlink(const char *, char *, size_t)
{
    return -1;
}
