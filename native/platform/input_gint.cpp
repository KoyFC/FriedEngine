#include "platform/input.h"

#include <cstring>

namespace
{
    // SDL's scancode range, which fried.input.Key takes its values from.
    constexpr int s_scancodeCount = 512;

    bool s_down[s_scancodeCount] = {};
    bool s_previous[s_scancodeCount] = {};

    bool isScancode(int scancode)
    {
        return scancode >= 0 && scancode < s_scancodeCount;
    }
}

void fried_input_report_key(int scancode, bool down)
{
    if (isScancode(scancode))
    {
        s_down[scancode] = down;
    }
}

int fried_input_is_key_pressed(int scancode)
{
    return isScancode(scancode) && s_down[scancode];
}

int fried_input_is_key_down(int scancode)
{
    return isScancode(scancode) && s_down[scancode] && !s_previous[scancode];
}

int fried_input_is_key_released(int scancode)
{
    return isScancode(scancode) && !s_down[scancode] && s_previous[scancode];
}

void fried_input_end_frame()
{
    std::memcpy(s_previous, s_down, sizeof(s_previous));
}
