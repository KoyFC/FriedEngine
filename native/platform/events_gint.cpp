#include "platform/events.h"

#include "platform/input.h"
#include "platform/window.h"

#include <gint/gint.h>
#include <gint/keyboard.h>

#include <vector>

namespace
{
    struct WindowEvent
    {
        int m_windowId;
        int m_type;
    };

    struct InputEvent
    {
        int m_type;
        int m_windowId;
        int m_code;
    };

    std::vector<WindowEvent> s_windowEvents;
    int s_currentEvent = -1;

    std::vector<InputEvent> s_inputEvents;
    int s_currentInputEvent = -1;

    // fried.input.Key holds SDL scancodes. A key that types a digit is that
    // digit, one that does what a keyboard key does (the arrows, EXE, EXIT,
    // DEL, F1 to F6, SHIFT, ALPHA) is that key, and the twelve keys above the
    // digits are the letters ALPHA types with them, A to L. The point key,
    // which ALPHA types a space with, is Space. MENU stays the calculator's
    // own and leaves to the main menu, as it does in every other add-in.
    int scancodeOf(int key)
    {
        switch (key)
        {
        case KEY_XOT: return 4;
        case KEY_LOG: return 5;
        case KEY_LN: return 6;
        case KEY_SIN: return 7;
        case KEY_COS: return 8;
        case KEY_TAN: return 9;
        case KEY_FRAC: return 10;
        case KEY_FD: return 11;
        case KEY_LEFTP: return 12;
        case KEY_RIGHTP: return 13;
        case KEY_COMMA: return 14;
        case KEY_ARROW: return 15;
        case KEY_1: return 30;
        case KEY_2: return 31;
        case KEY_3: return 32;
        case KEY_4: return 33;
        case KEY_5: return 34;
        case KEY_6: return 35;
        case KEY_7: return 36;
        case KEY_8: return 37;
        case KEY_9: return 38;
        case KEY_0: return 39;
        case KEY_EXE: return 40;
        case KEY_EXIT: return 41;
        case KEY_DEL: return 42;
        case KEY_DOT: return 44;
        case KEY_F1: return 58;
        case KEY_F2: return 59;
        case KEY_F3: return 60;
        case KEY_F4: return 61;
        case KEY_F5: return 62;
        case KEY_F6: return 63;
        case KEY_RIGHT: return 79;
        case KEY_LEFT: return 80;
        case KEY_DOWN: return 81;
        case KEY_UP: return 82;
        case KEY_SHIFT: return 225;
        case KEY_ALPHA: return 226;
        default: return -1;
        }
    }

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

    // The keys always go to the screen, which is window 0 while it is open.
    int screenWindowId()
    {
        return fried_window_get_width(0) > 0 ? 0 : -1;
    }

    void queueWindowEvent(int type)
    {
        int windowId = screenWindowId();
        if (windowId >= 0)
        {
            s_windowEvents.push_back({windowId, type});
        }
    }

    void leaveToMainMenu()
    {
        queueWindowEvent(FRIED_WINDOW_EVENT_FOCUS_LOST);
        gint_osmenu();
        queueWindowEvent(FRIED_WINDOW_EVENT_FOCUS_GAINED);
    }
}

int fried_events_pump()
{
    s_windowEvents.clear();
    s_currentEvent = -1;
    s_inputEvents.clear();
    s_currentInputEvent = -1;

    for (key_event_t event = pollevent(); event.type != KEYEV_NONE; event = pollevent())
    {
        if (event.type != KEYEV_DOWN && event.type != KEYEV_UP)
        {
            continue;
        }

        if (event.key == KEY_MENU)
        {
            if (event.type == KEYEV_DOWN)
            {
                leaveToMainMenu();
            }
            continue;
        }

        int scancode = scancodeOf(event.key);
        if (scancode < 0)
        {
            continue;
        }

        bool down = event.type == KEYEV_DOWN;
        fried_input_report_key(scancode, down);
        s_inputEvents.push_back({down ? FRIED_INPUT_EVENT_KEY_DOWN : FRIED_INPUT_EVENT_KEY_UP, screenWindowId(), scancode});
    }

    // The calculator has no way to close an add-in other than leaving it.
    return 0;
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
    const InputEvent *event = currentInputEvent();
    return event ? event->m_windowId : -1;
}

int fried_events_get_input_code()
{
    const InputEvent *event = currentInputEvent();
    return event ? event->m_code : 0;
}

// Keys carry nothing but their code, and they are the only input there is.
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
