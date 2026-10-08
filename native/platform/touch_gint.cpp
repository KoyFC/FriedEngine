#include "platform/touch.h"

// The calculator's screen is not a touchscreen, so there is no touch device.

int fried_touch_get_device_count()
{
    return 0;
}

int fried_touch_get_finger_count(int)
{
    return 0;
}

int fried_touch_get_finger_id(int, int)
{
    return -1;
}

int fried_touch_get_x(int, int)
{
    return 0;
}

int fried_touch_get_y(int, int)
{
    return 0;
}

int fried_touch_is_down(int)
{
    return 0;
}

int fried_touch_is_released(int)
{
    return 0;
}

void fried_touch_end_frame()
{
}
