#pragma once

enum FriedWindowEventType
{
    FRIED_WINDOW_EVENT_NONE = 0,
    FRIED_WINDOW_EVENT_CLOSE = 1,
    FRIED_WINDOW_EVENT_RESIZED = 2,
    FRIED_WINDOW_EVENT_FOCUS_GAINED = 3,
    FRIED_WINDOW_EVENT_FOCUS_LOST = 4,
};

extern "C"
{
    // Returns non-zero if an SDL_QUIT event was seen.
    int fried_events_pump();

    // Advances to the next window event of this frame, described by the
    // getters below, and returns FRIED_WINDOW_EVENT_NONE once drained.
    int fried_events_poll_window_event();
    int fried_events_get_window_id();
    int fried_events_get_data1();
    int fried_events_get_data2();
}
