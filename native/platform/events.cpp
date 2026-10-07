#include "platform/events.h"
#include "platform/gamepad.h"
#include "platform/mouse.h"
#include "platform/touch.h"
#include "platform/window.h"

#include <SDL.h>
#include <vector>

namespace
{
    struct WindowEvent
    {
        int m_windowId;
        int m_type;
        int m_data1;
        int m_data2;
    };

    struct InputEvent
    {
        int m_type;
        int m_windowId;
        int m_code;
        int m_device;
        int m_x;
        int m_y;
        double m_scrollX;
        double m_scrollY;
        double m_value;
    };

    std::vector<WindowEvent> s_windowEvents;
    int s_currentEvent = -1;

    std::vector<InputEvent> s_inputEvents;
    int s_currentInputEvent = -1;
    double s_lastAxisValue[SDL_CONTROLLER_AXIS_MAX] = {};

    const WindowEvent *currentEvent()
    {
        if (s_currentEvent < 0 || s_currentEvent >= (int)s_windowEvents.size())
        {
            return nullptr;
        }
        return &s_windowEvents[s_currentEvent];
    }

    const InputEvent *currentInputEvent()
    {
        if (s_currentInputEvent < 0 || s_currentInputEvent >= (int)s_inputEvents.size())
        {
            return nullptr;
        }
        return &s_inputEvents[s_currentInputEvent];
    }

    void queueWindowEvent(const SDL_WindowEvent &event)
    {
        int type = FRIED_WINDOW_EVENT_NONE;
        int data1 = 0;
        int data2 = 0;

        switch (event.event)
        {
        case SDL_WINDOWEVENT_CLOSE:
            type = FRIED_WINDOW_EVENT_CLOSE;
            break;
        // RESIZED only covers resizes the user or window manager caused,
        // SIZE_CHANGED also the ones the engine itself causes.
        case SDL_WINDOWEVENT_SIZE_CHANGED:
            type = FRIED_WINDOW_EVENT_RESIZED;
            data1 = event.data1;
            data2 = event.data2;
            break;
        case SDL_WINDOWEVENT_FOCUS_GAINED:
            type = FRIED_WINDOW_EVENT_FOCUS_GAINED;
            break;
        case SDL_WINDOWEVENT_FOCUS_LOST:
            type = FRIED_WINDOW_EVENT_FOCUS_LOST;
            break;
        default:
            return;
        }

        int windowId = fried_window_find_by_sdl_id(event.windowID);
        if (windowId < 0)
        {
            return;
        }

        s_windowEvents.push_back({windowId, type, data1, data2});
    }

    InputEvent &queueInputEvent(int type, unsigned int sdlWindowId)
    {
        s_inputEvents.push_back({type, fried_window_find_by_sdl_id(sdlWindowId), 0, 0, 0, 0, 0.0, 0.0, 0.0});
        return s_inputEvents.back();
    }

    void queueKeyEvent(const SDL_KeyboardEvent &event, int type)
    {
        // Repeats come at the desktop's own rate and say nothing about a key
        // going down, so only the first one is queued.
        if (event.repeat != 0)
        {
            return;
        }
        queueInputEvent(type, event.windowID).m_code = event.keysym.scancode;
    }

    void queueMouseButtonEvent(const SDL_MouseButtonEvent &event, int type)
    {
        InputEvent &queued = queueInputEvent(type, event.windowID);
        queued.m_code = event.button;
        queued.m_x = event.x;
        queued.m_y = event.y;
    }

    void queueMouseMotionEvent(const SDL_MouseMotionEvent &event)
    {
        InputEvent &queued = queueInputEvent(FRIED_INPUT_EVENT_MOUSE_MOVED, event.windowID);
        queued.m_x = event.x;
        queued.m_y = event.y;
    }

    void queueMouseWheelEvent(const SDL_MouseWheelEvent &event, int x, int y)
    {
        InputEvent &queued = queueInputEvent(FRIED_INPUT_EVENT_MOUSE_WHEEL, event.windowID);
        queued.m_scrollX = x;
        queued.m_scrollY = y;
    }

    void queueTouchEvent(const SDL_TouchFingerEvent &event, int type)
    {
        FriedTouchPoint point;
        if (!fried_touch_report(event, point))
        {
            return;
        }
        InputEvent &queued = queueInputEvent(type, event.windowID);
        queued.m_code = point.m_fingerId;
        queued.m_device = point.m_device;
        queued.m_x = point.m_x;
        queued.m_y = point.m_y;
    }

    void queueGamepadButtonEvent(const SDL_ControllerButtonEvent &event, int type)
    {
        if (!fried_gamepad_is_active_instance(event.which))
        {
            return;
        }
        queueInputEvent(type, 0).m_code = fried_gamepad_convert_button_layout(event.button);
    }

    void queueGamepadAxisEvent(const SDL_ControllerAxisEvent &event)
    {
        if (!fried_gamepad_is_active_instance(event.which) || event.axis >= SDL_CONTROLLER_AXIS_MAX)
        {
            return;
        }

        // A stick at rest reports noise that the deadzone flattens to the same
        // zero, so the deadzoned value is what the comparison has to use.
        double value = fried_gamepad_normalize_axis(event.value);
        if (value == s_lastAxisValue[event.axis])
        {
            return;
        }
        s_lastAxisValue[event.axis] = value;

        InputEvent &queued = queueInputEvent(FRIED_INPUT_EVENT_GAMEPAD_AXIS_MOVED, 0);
        queued.m_code = event.axis;
        queued.m_value = value;
    }
}

int fried_events_pump()
{
    s_windowEvents.clear();
    s_currentEvent = -1;
    s_inputEvents.clear();
    s_currentInputEvent = -1;

    SDL_Event event;
    int quitRequested = 0;
    while (SDL_PollEvent(&event))
    {
        switch (event.type)
        {
        case SDL_QUIT:
            quitRequested = 1;
            break;
        case SDL_KEYDOWN:
            queueKeyEvent(event.key, FRIED_INPUT_EVENT_KEY_DOWN);
            break;
        case SDL_KEYUP:
            queueKeyEvent(event.key, FRIED_INPUT_EVENT_KEY_UP);
            break;
        case SDL_MOUSEBUTTONDOWN:
            queueMouseButtonEvent(event.button, FRIED_INPUT_EVENT_MOUSE_BUTTON_DOWN);
            break;
        case SDL_MOUSEBUTTONUP:
            queueMouseButtonEvent(event.button, FRIED_INPUT_EVENT_MOUSE_BUTTON_UP);
            break;
        case SDL_MOUSEMOTION:
            queueMouseMotionEvent(event.motion);
            break;
        case SDL_MOUSEWHEEL:
        {
            int x = event.wheel.x;
            int y = event.wheel.y;
            if (event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED)
            {
                x = -x;
                y = -y;
            }
            fried_mouse_report_wheel(x, y);
            queueMouseWheelEvent(event.wheel, x, y);
            break;
        }
        case SDL_FINGERDOWN:
            queueTouchEvent(event.tfinger, FRIED_INPUT_EVENT_TOUCH_DOWN);
            break;
        case SDL_FINGERUP:
            queueTouchEvent(event.tfinger, FRIED_INPUT_EVENT_TOUCH_UP);
            break;
        case SDL_FINGERMOTION:
            queueTouchEvent(event.tfinger, FRIED_INPUT_EVENT_TOUCH_MOVED);
            break;
        case SDL_CONTROLLERBUTTONDOWN:
            queueGamepadButtonEvent(event.cbutton, FRIED_INPUT_EVENT_GAMEPAD_BUTTON_DOWN);
            break;
        case SDL_CONTROLLERBUTTONUP:
            queueGamepadButtonEvent(event.cbutton, FRIED_INPUT_EVENT_GAMEPAD_BUTTON_UP);
            break;
        case SDL_CONTROLLERAXISMOTION:
            queueGamepadAxisEvent(event.caxis);
            break;
        case SDL_CONTROLLERDEVICEADDED:
            fried_gamepad_report_added(event.cdevice.which);
            break;
        case SDL_CONTROLLERDEVICEREMOVED:
            fried_gamepad_report_removed(event.cdevice.which);
            break;
        case SDL_WINDOWEVENT:
            queueWindowEvent(event.window);
            break;
        default:
            break;
        }
    }
    return quitRequested;
}

int fried_events_poll_window_event()
{
    if (s_currentEvent + 1 >= (int)s_windowEvents.size())
    {
        return FRIED_WINDOW_EVENT_NONE;
    }
    s_currentEvent++;
    return s_windowEvents[s_currentEvent].m_type;
}

int fried_events_get_window_id()
{
    const WindowEvent *event = currentEvent();
    return event ? event->m_windowId : -1;
}

int fried_events_get_data1()
{
    const WindowEvent *event = currentEvent();
    return event ? event->m_data1 : 0;
}

int fried_events_get_data2()
{
    const WindowEvent *event = currentEvent();
    return event ? event->m_data2 : 0;
}

int fried_events_poll_input_event()
{
    if (s_currentInputEvent + 1 >= (int)s_inputEvents.size())
    {
        return FRIED_INPUT_EVENT_NONE;
    }
    s_currentInputEvent++;
    return s_inputEvents[s_currentInputEvent].m_type;
}

int fried_events_get_input_window_id()
{
    const InputEvent *event = currentInputEvent();
    return event ? event->m_windowId : -1;
}

int fried_events_get_input_code()
{
    const InputEvent *event = currentInputEvent();
    return event ? event->m_code : 0;
}

int fried_events_get_input_device()
{
    const InputEvent *event = currentInputEvent();
    return event ? event->m_device : 0;
}

int fried_events_get_input_x()
{
    const InputEvent *event = currentInputEvent();
    return event ? event->m_x : 0;
}

int fried_events_get_input_y()
{
    const InputEvent *event = currentInputEvent();
    return event ? event->m_y : 0;
}

double fried_events_get_input_scroll_x()
{
    const InputEvent *event = currentInputEvent();
    return event ? event->m_scrollX : 0.0;
}

double fried_events_get_input_scroll_y()
{
    const InputEvent *event = currentInputEvent();
    return event ? event->m_scrollY : 0.0;
}

double fried_events_get_input_value()
{
    const InputEvent *event = currentInputEvent();
    return event ? event->m_value : 0.0;
}
