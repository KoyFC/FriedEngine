#include "platform/window.h"

#include "last_error.h"
#include "platform/console_nds.h"

#include <sys/stat.h>

#include <cstdio>

// Each screen is a window, the top one opened first: window 0 is the top
// screen and window 1 the bottom one, which the text console gives up while
// it is open. A window is always the whole screen, and has no title bar to
// put a title or an icon in.

namespace
{
    constexpr int s_screenWidth = 256;
    constexpr int s_screenHeight = 192;
    constexpr int s_bottomWindowId = 1;

    bool s_open[FRIED_MAX_WINDOWS] = {};

    bool isOpen(int windowId)
    {
        return windowId >= 0 && windowId < FRIED_MAX_WINDOWS && s_open[windowId];
    }
}

int fried_window_get_max_count()
{
    return FRIED_MAX_WINDOWS;
}

int fried_window_create(const char *, int, int)
{
    int windowId = 0;
    while (windowId < FRIED_MAX_WINDOWS && s_open[windowId])
    {
        ++windowId;
    }
    if (windowId == FRIED_MAX_WINDOWS)
    {
        char message[128];
        std::snprintf(
            message, sizeof(message),
            "This platform shows at most %d window(s) at a time",
            FRIED_MAX_WINDOWS);
        fried_set_last_error(message);
        return -1;
    }
    s_open[windowId] = true;
    if (windowId == s_bottomWindowId)
    {
        fried_console_release_screen();
    }
    return windowId;
}

void fried_window_destroy(int windowId)
{
    if (!isOpen(windowId))
    {
        return;
    }
    s_open[windowId] = false;
    if (windowId == s_bottomWindowId)
    {
        fried_console_reclaim_screen();
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
