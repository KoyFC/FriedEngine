#include "window.h"

#include <SDL.h>
#include <vector>

namespace
{
    std::vector<SDL_Window *> g_windows;
}

int fried_window_create(const char *title, int width, int height)
{
    SDL_Window *window = SDL_CreateWindow(
        title,
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        width, height,
        SDL_WINDOW_SHOWN);
    if (!window)
    {
        return -1;
    }

    SDL_Surface *surface = SDL_GetWindowSurface(window);
    if (surface)
    {
        SDL_FillRect(surface, nullptr, SDL_MapRGB(surface->format, 0, 0, 0));
        SDL_UpdateWindowSurface(window);
    }

    g_windows.push_back(window);
    return (int)(g_windows.size() - 1);
}

void fried_window_destroy(int windowId)
{
    if (windowId < 0 || windowId >= (int)g_windows.size() || !g_windows[windowId])
    {
        return;
    }
    SDL_DestroyWindow(g_windows[windowId]);
    g_windows[windowId] = nullptr;
}

int fried_window_get_width(int windowId)
{
    if (windowId < 0 || windowId >= (int)g_windows.size() || !g_windows[windowId])
    {
        return 0;
    }
    int width, height;
    SDL_GetWindowSize(g_windows[windowId], &width, &height);
    return width;
}

int fried_window_get_height(int windowId)
{
    if (windowId < 0 || windowId >= (int)g_windows.size() || !g_windows[windowId])
    {
        return 0;
    }
    int width, height;
    SDL_GetWindowSize(g_windows[windowId], &width, &height);
    return height;
}
