#pragma once

struct SDL_TouchFingerEvent;

extern "C"
{
    int fried_touch_get_device_count();
    int fried_touch_get_finger_count(int device);
    int fried_touch_get_finger_id(int device, int index);
    int fried_touch_get_x(int device, int index);
    int fried_touch_get_y(int device, int index);
    int fried_touch_is_down(int device);
    int fried_touch_is_released(int device);
    void fried_touch_end_frame();
}

struct FriedTouchPoint
{
    int m_device;
    int m_fingerId;
    int m_windowId;
    int m_x;
    int m_y;
};

bool fried_touch_report(const SDL_TouchFingerEvent &event, FriedTouchPoint &point);

#ifdef __NDS__
#include "platform/events.h"

// Reads the touchscreen, once a frame, and hands report a touch event of
// events.h for each change: down, moved or up.
void fried_touch_poll(void (*report)(int type, int windowId, int x, int y));
#endif
