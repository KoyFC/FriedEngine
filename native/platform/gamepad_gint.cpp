#include "platform/gamepad.h"

// The calculator has no gamepad, so one never connects and every button reads
// up. Only the deadzone is kept, since a game may set it and read it back.

namespace
{
    constexpr int s_southButton = 0;
    constexpr int s_eastButton = 1;

    double s_deadzone = 0.25;
}

void fried_gamepad_init()
{
}

void fried_gamepad_shutdown()
{
}

int fried_gamepad_is_connected()
{
    return 0;
}

int fried_gamepad_is_button_pressed(int)
{
    return 0;
}

int fried_gamepad_is_button_down(int)
{
    return 0;
}

int fried_gamepad_is_button_released(int)
{
    return 0;
}

int fried_gamepad_get_accept_button()
{
    return s_southButton;
}

int fried_gamepad_get_cancel_button()
{
    return s_eastButton;
}

double fried_gamepad_get_axis(int)
{
    return 0.0;
}

double fried_gamepad_get_deadzone()
{
    return s_deadzone;
}

void fried_gamepad_set_deadzone(double deadzone)
{
    if (deadzone < 0.0)
    {
        deadzone = 0.0;
    }
    if (deadzone > 1.0)
    {
        deadzone = 1.0;
    }
    s_deadzone = deadzone;
}

void fried_gamepad_end_frame()
{
}
