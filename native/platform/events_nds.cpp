#include "platform/events.h"

// Neither screen can be closed, moved or resized, and a DS program is left by
// turning the console off, so no window event ever arrives.

int fried_events_pump()
{
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
    return FRIED_INPUT_EVENT_NONE;
}

int fried_events_get_input_window_id()
{
    return -1;
}

int fried_events_get_input_code()
{
    return 0;
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
