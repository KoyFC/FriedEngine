#include "platform/touch.h"

#include "graphics/renderer.h"
#include "platform/window.h"

#include <SDL.h>
#include <vector>

namespace
{
    struct Finger
    {
        SDL_FingerID m_id;
        int m_x;
        int m_y;
    };

    struct Device
    {
        SDL_TouchID m_id;
        std::vector<Finger> m_fingers;
        bool m_down;
        bool m_released;
    };

    std::vector<Device> s_devices;

    int indexOfDevice(SDL_TouchID id)
    {
        for (int i = 0; i < SDL_GetNumTouchDevices(); ++i)
        {
            if (SDL_GetTouchDevice(i) == id)
            {
                return i;
            }
        }
        return -1;
    }

    Device &findOrAddDevice(SDL_TouchID id)
    {
        for (Device &device : s_devices)
        {
            if (device.m_id == id)
            {
                return device;
            }
        }
        s_devices.push_back({id, {}, false, false});
        return s_devices.back();
    }

    const Device *deviceAt(int index)
    {
        if (index < 0 || index >= SDL_GetNumTouchDevices())
        {
            return nullptr;
        }
        SDL_TouchID id = SDL_GetTouchDevice(index);
        for (const Device &device : s_devices)
        {
            if (device.m_id == id)
            {
                return &device;
            }
        }
        return nullptr;
    }

    const Finger *fingerAt(int device, int index)
    {
        const Device *found = deviceAt(device);
        if (found == nullptr || index < 0 || index >= (int)found->m_fingers.size())
        {
            return nullptr;
        }
        return &found->m_fingers[index];
    }
}

int fried_touch_get_device_count()
{
    return SDL_GetNumTouchDevices();
}

int fried_touch_get_finger_count(int device)
{
    const Device *found = deviceAt(device);
    return found ? (int)found->m_fingers.size() : 0;
}

int fried_touch_get_finger_id(int device, int index)
{
    const Finger *finger = fingerAt(device, index);
    return finger ? (int)finger->m_id : -1;
}

int fried_touch_get_x(int device, int index)
{
    const Finger *finger = fingerAt(device, index);
    return finger ? finger->m_x : 0;
}

int fried_touch_get_y(int device, int index)
{
    const Finger *finger = fingerAt(device, index);
    return finger ? finger->m_y : 0;
}

int fried_touch_is_down(int device)
{
    const Device *found = deviceAt(device);
    return found && found->m_down;
}

int fried_touch_is_released(int device)
{
    const Device *found = deviceAt(device);
    return found && found->m_released;
}

void fried_touch_end_frame()
{
    for (Device &device : s_devices)
    {
        device.m_down = false;
        device.m_released = false;
    }
}

bool fried_touch_report(const SDL_TouchFingerEvent &event, FriedTouchPoint &point)
{
    int windowId = fried_window_find_by_sdl_id(event.windowID);
    Device &device = findOrAddDevice(event.touchId);

    auto finger = device.m_fingers.begin();
    while (finger != device.m_fingers.end() && finger->m_id != event.fingerId)
    {
        ++finger;
    }

    if (event.type == SDL_FINGERDOWN && finger == device.m_fingers.end() && windowId >= 0)
    {
        device.m_fingers.push_back({event.fingerId, 0, 0});
        finger = device.m_fingers.end() - 1;
        device.m_down = true;
    }

    if (finger == device.m_fingers.end())
    {
        return false;
    }

    if (windowId >= 0)
    {
        fried_renderer_touch_to_logical(windowId, event.x, event.y, finger->m_x, finger->m_y);
    }
    point = {indexOfDevice(event.touchId), (int)event.fingerId, windowId, finger->m_x, finger->m_y};

    if (event.type == SDL_FINGERUP)
    {
        device.m_fingers.erase(finger);
        device.m_released = true;
    }

    return windowId >= 0;
}
