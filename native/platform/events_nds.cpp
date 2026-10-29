#include "platform/events.h"

#include "platform/gamepad.h"

#include <vector>

// Neither screen can be closed, moved or resized, and a DS program is left by
// turning the console off, so no window event ever arrives. The buttons are a
// gamepad's, which belong to no window.

namespace
{
    struct InputEvent
    {
        int m_type;
        int m_code;
    };

    std::vector<InputEvent> s_inputEvents;
    int s_currentInputEvent = -1;

    const InputEvent *currentInputEvent()
    {
        if (s_currentInputEvent < 0 || s_currentInputEvent >= (int)s_inputEvents.size())
        {
            return nullptr;
        }
        return &s_inputEvents[s_currentInputEvent];
    }

    void queueButton(int button, bool down)
    {
        s_inputEvents.push_back({down ? FRIED_INPUT_EVENT_GAMEPAD_BUTTON_DOWN : FRIED_INPUT_EVENT_GAMEPAD_BUTTON_UP, button});
    }
}

int fried_events_pump()
{
    s_inputEvents.clear();
    s_currentInputEvent = -1;
    fried_gamepad_poll(queueButton);
    return 0;
}

int fried_events_poll_window_event()
{
    return FRIED_WINDOW_EVENT_NONE;
}

int fried_events_get_window_id()
{
    return -1;
}

int fried_events_get_data1()
{
    return 0;
}

int fried_events_get_data2()
{
    return 0;
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
    return -1;
}

int fried_events_get_input_code()
{
    const InputEvent *event = currentInputEvent();
    return event ? event->m_code : 0;
}

int fried_events_get_input_device()
{
    return 0;
}

int fried_events_get_input_x()
{
    return 0;
}

int fried_events_get_input_y()
{
    return 0;
}

double fried_events_get_input_scroll_x()
{
    return 0.0;
}

double fried_events_get_input_scroll_y()
{
    return 0.0;
}

double fried_events_get_input_value()
{
    return 0.0;
}
