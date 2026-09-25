#include "window.h"

#include <SDL.h>
#include <vector>

namespace
{
    std::vector<SDL_Window *> s_windows;
    std::vector<int> s_freeWindowIds;
}

SDL_Window *fried_window_get_sdl(int windowId)
{
    if (windowId < 0 || windowId >= (int)s_windows.size())
    {
        return nullptr;
    }
    return s_windows[windowId];
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

    if (!s_freeWindowIds.empty())
    {
        int windowId = s_freeWindowIds.back();
        s_freeWindowIds.pop_back();
        s_windows[windowId] = window;
        return windowId;
    }

    s_windows.push_back(window);
    return (int)(s_windows.size() - 1);
}

void fried_window_destroy(int windowId)
{
    SDL_Window *window = fried_window_get_sdl(windowId);
    if (!window)
    {
        return;
    }
    SDL_DestroyWindow(window);
    s_windows[windowId] = nullptr;
    s_freeWindowIds.push_back(windowId);
}

int fried_window_get_width(int windowId)
{
    SDL_Window *window = fried_window_get_sdl(windowId);
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
    SDL_Window *window = fried_window_get_sdl(windowId);
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

