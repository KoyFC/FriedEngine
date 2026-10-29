#include "platform/gamepad.h"

#include <nds.h>

// The DS's own buttons are the one gamepad, always connected. They are
// placed the way a gamepad's are, by position, so A is east and B south, and
// A accepts as it does on every Nintendo console. There is no stick and there
// are no triggers, so every axis reads zero and L2 and R2 never go down.

namespace
{
    constexpr int s_southButton = 0;
    constexpr int s_eastButton = 1;

    struct Mapping
    {
        uint32_t m_key;
        int m_button;
    };

    // In the engine's button order, fried.input.GamepadButton.
    constexpr Mapping s_mappings[] = {
        {KEY_B, 0},
        {KEY_A, 1},
        {KEY_Y, 2},
        {KEY_X, 3},
        {KEY_SELECT, 4},
        {KEY_START, 6},
        {KEY_L, 9},
        {KEY_R, 10},
        {KEY_UP, 11},
        {KEY_DOWN, 12},
        {KEY_LEFT, 13},
        {KEY_RIGHT, 14},
    };

    uint32_t s_held = 0;
    uint32_t s_previous = 0;
    double s_deadzone = 0.25;

    uint32_t keyOf(int button)
    {
        for (const Mapping &mapping : s_mappings)
        {
            if (mapping.m_button == button)
            {
                return mapping.m_key;
            }
        }
        return 0;
    }
}

void fried_gamepad_poll(void (*report)(int button, bool down))
{
    scanKeys();
    uint32_t held = keysHeld();
    uint32_t changed = held ^ s_held;
    s_held = held;
    for (const Mapping &mapping : s_mappings)
    {
        if (changed & mapping.m_key)
        {
            report(mapping.m_button, (held & mapping.m_key) != 0);
        }
    }
}

void fried_gamepad_init()
{
}

void fried_gamepad_shutdown()
{
}

int fried_gamepad_is_connected()
{
    return 1;
}

int fried_gamepad_is_button_pressed(int button)
{
    return (s_held & keyOf(button)) != 0;
}

int fried_gamepad_is_button_down(int button)
{
    uint32_t key = keyOf(button);
    return (s_held & key) && !(s_previous & key);
}

int fried_gamepad_is_button_released(int button)
{
    uint32_t key = keyOf(button);
    return !(s_held & key) && (s_previous & key);
}

int fried_gamepad_get_accept_button()
{
    return s_eastButton;
}

int fried_gamepad_get_cancel_button()
{
    return s_southButton;
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
    s_previous = s_held;
}
