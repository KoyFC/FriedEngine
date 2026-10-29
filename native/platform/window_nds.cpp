#include "platform/window.h"

#include "last_error.h"

#include <sys/stat.h>

#include <cstdio>

// The window is the top screen: there is one, it is always the whole screen,
// and it has no title bar to put a title or an icon in.

namespace
{
    constexpr int s_screenWidth = 256;
    constexpr int s_screenHeight = 192;
    constexpr int s_windowId = 0;

    bool s_open = false;

    bool isOpen(int windowId)
    {
        return s_open && windowId == s_windowId;
    }
}

int fried_window_get_max_count()
{
    return FRIED_MAX_WINDOWS;
}

int fried_window_create(const char *, int, int)
{
    if (s_open)
    {
        char message[128];
        std::snprintf(
            message, sizeof(message),
            "This platform shows at most %d window(s) at a time",
            FRIED_MAX_WINDOWS);
        fried_set_last_error(message);
        return -1;
    }
    s_open = true;
    return s_windowId;
}

void fried_window_destroy(int windowId)
{
    if (isOpen(windowId))
    {
        s_open = false;
    }
}

// The menu icon is the ROM's own, so a missing file is the only thing to
// report.
bool fried_window_set_icon(int windowId, const char *path)
{
    if (!isOpen(windowId) || !path)
    {
        fried_set_last_error("No such window, or no path given");
        return false;
    }

    struct stat status;
    if (stat(path, &status) != 0)
    {
        fried_set_last_error("No such file");
        return false;
    }
    return true;
}

int fried_window_get_width(int windowId)
{
    return isOpen(windowId) ? s_screenWidth : 0;
}

int fried_window_get_height(int windowId)
{
    return isOpen(windowId) ? s_screenHeight : 0;
}

int fried_window_get_x(int)
{
    return 0;
}

int fried_window_get_y(int)
{
    return 0;
}

void fried_window_set_position(int, int, int)
{
}
