#include "window.h"

#include <SDL.h>
#include <vector>

namespace
{
    std::vector<SDL_Window *> s_windows;

    SDL_Window *windowAt(int windowId)
    {
        if (windowId < 0 || windowId >= (int)s_windows.size())
        {
            return nullptr;
        }
        return s_windows[windowId];
    }

    void paintBackground(SDL_Window *window)
    {
        SDL_Surface *surface = SDL_GetWindowSurface(window);
        if (!surface)
        {
            return;
        }
        SDL_FillRect(surface, nullptr, SDL_MapRGB(surface->format, 0, 0, 0));
        SDL_UpdateWindowSurface(window);
    }
}

int fried_window_create(const char *title, int width, int height)
{
    SDL_Window *window = SDL_CreateWindow(
        title,
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        width, height,
        SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
    if (!window)
    {
        return -1;
    }

    paintBackground(window);

    s_windows.push_back(window);
    return (int)(s_windows.size() - 1);
}

void fried_window_destroy(int windowId)
{
    SDL_Window *window = windowAt(windowId);
    if (!window)
    {
        return;
    }
    SDL_DestroyWindow(window);
    s_windows[windowId] = nullptr;
}

int fried_window_get_width(int windowId)
{
    SDL_Window *window = windowAt(windowId);
    if (!window)
    {
        return 0;
    }
    int width, height;
    SDL_GetWindowSize(window, &width, &height);
    return width;
}

int fried_window_get_height(int windowId)
{
    SDL_Window *window = windowAt(windowId);
    if (!window)
    {
        return 0;
    }
    int width, height;
    SDL_GetWindowSize(window, &width, &height);
    return height;
}

int fried_window_find_by_sdl_id(unsigned int sdlWindowId)
{
    for (int i = 0; i < (int)s_windows.size(); ++i)
    {
        if (s_windows[i] && SDL_GetWindowID(s_windows[i]) == (Uint32)sdlWindowId)
        {
            return i;
        }
    }
    return -1;
}

void fried_window_present_all()
{
    for (SDL_Window *window : s_windows)
    {
        if (window)
        {
            paintBackground(window);
        }
    }
}
