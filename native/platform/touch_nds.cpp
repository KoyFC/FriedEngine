#include "platform/touch.h"

#include "graphics/renderer.h"
#include "platform/window.h"

#include <nds.h>

// The touchscreen is one device with one finger, and belongs to the bottom
// screen's window, as on the 3DS: with no window there, a touch is no one's
// and nothing is reported. Its position is in the window's logical pixels.

namespace
{
    constexpr int s_bottomWindowId = 1;
    constexpr int s_screenWidth = 256;
    constexpr int s_screenHeight = 192;
    constexpr int s_fingerId = 0;

    bool s_touching = false;
    bool s_down = false;
    bool s_released = false;
    int s_x = 0;
    int s_y = 0;

    bool hasWindow()
    {
        return fried_window_get_width(s_bottomWindowId) > 0;
    }
}

void fried_touch_poll(void (*report)(int type, int windowId, int x, int y))
{
    TouchData touch;
    bool touching = touchRead(&touch) && hasWindow();
    if (!touching)
    {
        if (s_touching)
        {
            s_touching = false;
            s_released = true;
            report(FRIED_INPUT_EVENT_TOUCH_UP, s_bottomWindowId, s_x, s_y);
        }
        return;
    }

    int x = 0, y = 0;
    fried_renderer_touch_to_logical(s_bottomWindowId, (float)touch.px / s_screenWidth, (float)touch.py / s_screenHeight, x, y);
    if (!s_touching)
    {
        s_touching = true;
        s_down = true;
        s_x = x;
        s_y = y;
        report(FRIED_INPUT_EVENT_TOUCH_DOWN, s_bottomWindowId, x, y);
    }
    else if (x != s_x || y != s_y)
    {
        s_x = x;
        s_y = y;
        report(FRIED_INPUT_EVENT_TOUCH_MOVED, s_bottomWindowId, x, y);
    }
}

int fried_touch_get_device_count()
{
    return 1;
}

int fried_touch_get_finger_count(int device)
{
    return device == 0 && s_touching ? 1 : 0;
}

int fried_touch_get_finger_id(int device, int index)
{
    return fried_touch_get_finger_count(device) > index && index >= 0 ? s_fingerId : -1;
}

int fried_touch_get_x(int device, int index)
{
    return fried_touch_get_finger_count(device) > index && index >= 0 ? s_x : 0;
}

int fried_touch_get_y(int device, int index)
{
    return fried_touch_get_finger_count(device) > index && index >= 0 ? s_y : 0;
}

int fried_touch_is_down(int device)
{
    return device == 0 && s_down;
}

int fried_touch_is_released(int device)
{
    return device == 0 && s_released;
}

void fried_touch_end_frame()
{
    s_down = false;
    s_released = false;
}
