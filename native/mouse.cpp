#include "mouse.h"

#include <SDL.h>

namespace
{
    Uint32 s_previousButtons = 0;
    double s_scrollX = 0.0;
    double s_scrollY = 0.0;
}

int fried_mouse_get_x()
{
    int x;
    SDL_GetMouseState(&x, nullptr);
    return x;
}

int fried_mouse_get_y()
{
    int y;
    SDL_GetMouseState(nullptr, &y);
    return y;
}

int fried_mouse_is_button_pressed(int button)
{
    return (SDL_GetMouseState(nullptr, nullptr) & SDL_BUTTON(button)) != 0;
}

int fried_mouse_is_button_down(int button)
{
    Uint32 mask = SDL_BUTTON(button);
    Uint32 current = SDL_GetMouseState(nullptr, nullptr);
    return (current & mask) != 0 && (s_previousButtons & mask) == 0;
}

int fried_mouse_is_button_released(int button)
{
    Uint32 mask = SDL_BUTTON(button);
    Uint32 current = SDL_GetMouseState(nullptr, nullptr);
    return (current & mask) == 0 && (s_previousButtons & mask) != 0;
}

double fried_mouse_get_scroll_x()
{
    return s_scrollX;
}

double fried_mouse_get_scroll_y()
{
    return s_scrollY;
}

void fried_mouse_end_frame()
{
    s_previousButtons = SDL_GetMouseState(nullptr, nullptr);
    s_scrollX = 0.0;
    s_scrollY = 0.0;
}

void fried_mouse_report_wheel(int x, int y)
{
    s_scrollX += x;
    s_scrollY += y;
}
