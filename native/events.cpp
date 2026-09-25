#include "events.h"
#include "mouse.h"
#include "window.h"

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

    std::vector<WindowEvent> s_windowEvents;
    int s_currentEvent = -1;

    const WindowEvent *currentEvent()
    {
        if (s_currentEvent < 0 || s_currentEvent >= (int)s_windowEvents.size())
        {
            return nullptr;
        }
        return &s_windowEvents[s_currentEvent];
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
}

int fried_events_pump()
{
    s_windowEvents.clear();
    s_currentEvent = -1;

    SDL_Event event;
    int quitRequested = 0;
    while (SDL_PollEvent(&event))
    {
        if (event.type == SDL_QUIT)
        {
            quitRequested = 1;
        }
        else if (event.type == SDL_MOUSEWHEEL)
        {
            int x = event.wheel.x;
            int y = event.wheel.y;
            if (event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED)
            {
                x = -x;
                y = -y;
            }
            fried_mouse_report_wheel(x, y);
        }
        else if (event.type == SDL_WINDOWEVENT)
        {
            queueWindowEvent(event.window);
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
