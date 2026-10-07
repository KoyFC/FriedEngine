#include "platform/mouse.h"

#include "graphics/renderer.h"
#include "platform/window.h"

#include <SDL.h>

namespace
{
    Uint32 s_previousButtons = 0;

    void logicalPosition(int &x, int &y)
    {
        int windowX, windowY;
        SDL_GetMouseState(&windowX, &windowY);
        SDL_Window *focus = SDL_GetMouseFocus();
        int windowId = focus ? fried_window_find_by_sdl_id(SDL_GetWindowID(focus)) : -1;
        if (windowId < 0)
        {
            x = windowX;
            y = windowY;
            return;
        }
        fried_renderer_window_to_logical(windowId, windowX, windowY, x, y);
    }
    double s_scrollX = 0.0;
    double s_scrollY = 0.0;
}

int fried_mouse_get_x()
{
    int x, y;
    logicalPosition(x, y);
    return x;
}

int fried_mouse_get_y()
{
    int x, y;
    logicalPosition(x, y);
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
