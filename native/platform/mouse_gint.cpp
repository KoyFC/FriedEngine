#include "platform/mouse.h"

// The calculator has no pointer, so the mouse stays at the origin with every
// button up and never scrolls.

int fried_mouse_get_x()
{
    return 0;
}

int fried_mouse_get_y()
{
    return 0;
}

int fried_mouse_is_button_pressed(int)
{
    return 0;
}

int fried_mouse_is_button_down(int)
{
    return 0;
}

int fried_mouse_is_button_released(int)
{
    return 0;
}

double fried_mouse_get_scroll_x()
{
    return 0.0;
}

double fried_mouse_get_scroll_y()
{
    return 0.0;
}

void fried_mouse_end_frame()
{
}
