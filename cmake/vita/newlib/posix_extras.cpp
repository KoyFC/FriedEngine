#include <unistd.h>

// newlib declares readlink() but VitaSDK links no implementation. hxcpp calls
// it to read /proc/self/exe, a path the Vita does not have either.
extern "C" ssize_t readlink(const char *, char *, size_t)
{
    return -1;
}
