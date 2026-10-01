#pragma once

enum FriedWindowEventType
{
    FRIED_WINDOW_EVENT_NONE = 0,
    FRIED_WINDOW_EVENT_CLOSE = 1,
    FRIED_WINDOW_EVENT_RESIZED = 2,
    FRIED_WINDOW_EVENT_FOCUS_GAINED = 3,
    FRIED_WINDOW_EVENT_FOCUS_LOST = 4,
};

enum FriedInputEventType
{
    FRIED_INPUT_EVENT_NONE = 0,
    FRIED_INPUT_EVENT_KEY_DOWN = 1,
    FRIED_INPUT_EVENT_KEY_UP = 2,
    FRIED_INPUT_EVENT_MOUSE_BUTTON_DOWN = 3,
    FRIED_INPUT_EVENT_MOUSE_BUTTON_UP = 4,
    FRIED_INPUT_EVENT_MOUSE_MOVED = 5,
    FRIED_INPUT_EVENT_MOUSE_WHEEL = 6,
    FRIED_INPUT_EVENT_GAMEPAD_BUTTON_DOWN = 7,
    FRIED_INPUT_EVENT_GAMEPAD_BUTTON_UP = 8,
    FRIED_INPUT_EVENT_GAMEPAD_AXIS_MOVED = 9,
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

    // Each getter below reads zero for an event type that does not carry it,
    // and the window id is -1 for a gamepad event, which SDL reports with no
    // window at all.
    int fried_events_poll_input_event();
    int fried_events_get_input_window_id();
    int fried_events_get_input_code();
    int fried_events_get_input_x();
    int fried_events_get_input_y();
    double fried_events_get_input_scroll_x();
    double fried_events_get_input_scroll_y();
    double fried_events_get_input_value();
}
