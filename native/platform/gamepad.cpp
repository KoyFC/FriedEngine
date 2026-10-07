#include "platform/gamepad.h"

#include <SDL.h>
#include <cstring>

namespace
{
    // SDL has no controller button for either trigger, only an axis, so the
    // engine's own button enum appends the two ids past SDL's last one.
    constexpr int s_buttonL2 = SDL_CONTROLLER_BUTTON_MAX;
    constexpr int s_buttonR2 = SDL_CONTROLLER_BUTTON_MAX + 1;
    constexpr int s_buttonCount = SDL_CONTROLLER_BUTTON_MAX + 2;
    constexpr double s_triggerPressThreshold = 0.5;
    constexpr double s_axisRange = 32767.0;

    SDL_GameController *s_controller = nullptr;
    SDL_JoystickID s_instanceId = -1;
    Uint8 s_previousButtons[s_buttonCount] = {};
    double s_deadzone = 0.25;

    double clampAxis(int rawValue)
    {
        double value = rawValue / s_axisRange;
        return value < -1.0 ? -1.0 : value;
    }

    double applyDeadzone(double value)
    {
        double magnitude = value < 0.0 ? -value : value;
        return magnitude < s_deadzone ? 0.0 : value;
    }

    double rawAxis(int axis)
    {
        if (s_controller == nullptr || axis < 0 || axis >= SDL_CONTROLLER_AXIS_MAX)
        {
            return 0.0;
        }

        return clampAxis(SDL_GameControllerGetAxis(s_controller, (SDL_GameControllerAxis)axis));
    }

    Uint8 buttonState(int button)
    {
        if (s_controller == nullptr || button < 0 || button >= s_buttonCount)
        {
            return 0;
        }

        if (button == s_buttonL2)
        {
            return rawAxis(SDL_CONTROLLER_AXIS_TRIGGERLEFT) >= s_triggerPressThreshold;
        }
        if (button == s_buttonR2)
        {
            return rawAxis(SDL_CONTROLLER_AXIS_TRIGGERRIGHT) >= s_triggerPressThreshold;
        }

        return SDL_GameControllerGetButton(s_controller, (SDL_GameControllerButton)fried_gamepad_convert_button_layout(button));
    }

    void openFirstConnected()
    {
        for (int i = 0; i < SDL_NumJoysticks(); i++)
        {
            if (SDL_IsGameController(i))
            {
                fried_gamepad_report_added(i);
                return;
            }
        }
    }
}

int fried_gamepad_convert_button_layout(int button)
{
#ifdef __3DS__
    // SDL maps the 3DS face buttons by label, not position
    switch (button)
    {
    case SDL_CONTROLLER_BUTTON_A:
        return SDL_CONTROLLER_BUTTON_B;
    case SDL_CONTROLLER_BUTTON_B:
        return SDL_CONTROLLER_BUTTON_A;
    case SDL_CONTROLLER_BUTTON_X:
        return SDL_CONTROLLER_BUTTON_Y;
    case SDL_CONTROLLER_BUTTON_Y:
        return SDL_CONTROLLER_BUTTON_X;
    default:
        return button;
    }
#else
    return button;
#endif
}

void fried_gamepad_init()
{
    openFirstConnected();
}

void fried_gamepad_shutdown()
{
    if (s_controller != nullptr)
    {
        SDL_GameControllerClose(s_controller);
        s_controller = nullptr;
        s_instanceId = -1;
    }
    std::memset(s_previousButtons, 0, sizeof(s_previousButtons));
}

int fried_gamepad_is_connected()
{
    return s_controller != nullptr;
}

int fried_gamepad_is_button_pressed(int button)
{
    return buttonState(button) != 0;
}

int fried_gamepad_is_button_down(int button)
{
    if (button < 0 || button >= s_buttonCount)
    {
        return 0;
    }
    return buttonState(button) != 0 && s_previousButtons[button] == 0;
}

int fried_gamepad_is_button_released(int button)
{
    if (button < 0 || button >= s_buttonCount)
    {
        return 0;
    }
    return buttonState(button) == 0 && s_previousButtons[button] != 0;
}

double fried_gamepad_get_axis(int axis)
{
    return applyDeadzone(rawAxis(axis));
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
    for (int button = 0; button < s_buttonCount; button++)
    {
        s_previousButtons[button] = buttonState(button);
    }
}

int fried_gamepad_is_active_instance(int instanceId)
{
    return s_controller != nullptr && instanceId == s_instanceId;
}

double fried_gamepad_normalize_axis(int rawValue)
{
    return applyDeadzone(clampAxis(rawValue));
}

void fried_gamepad_report_added(int joystickIndex)
{
    if (s_controller != nullptr || !SDL_IsGameController(joystickIndex))
    {
        return;
    }

    s_controller = SDL_GameControllerOpen(joystickIndex);
    if (s_controller == nullptr)
    {
        return;
    }

    s_instanceId = SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(s_controller));
    std::memset(s_previousButtons, 0, sizeof(s_previousButtons));
}

void fried_gamepad_report_removed(int instanceId)
{
    if (s_controller == nullptr || instanceId != s_instanceId)
    {
        return;
    }

    SDL_GameControllerClose(s_controller);
    s_controller = nullptr;
    s_instanceId = -1;
    std::memset(s_previousButtons, 0, sizeof(s_previousButtons));

    openFirstConnected();
}
