#include "platform/window.h"

#include "handle_pool.h"
#include "last_error.h"

#include <SDL.h>
#include <SDL_image.h>

namespace
{
    HandlePool<SDL_Window> s_windows;
}

SDL_Window *fried_window_get_sdl(int windowId)
{
    return s_windows.get(windowId);
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
        fried_capture_sdl_error();
        return -1;
    }

    return s_windows.store(window);
}

void fried_window_destroy(int windowId)
{
    SDL_Window *window = s_windows.release(windowId);
    if (!window)
    {
        return;
    }
    SDL_DestroyWindow(window);
}

bool fried_window_set_icon(int windowId, const char *path)
{
    SDL_Window *window = fried_window_get_sdl(windowId);
    if (!window || !path)
    {
        fried_set_last_error("No such window, or no path given");
        return false;
    }

    SDL_Surface *icon = IMG_Load(path);
    if (!icon)
    {
        fried_capture_sdl_error();
        return false;
    }

    // SDL_SetWindowIcon copies the surface.
    SDL_SetWindowIcon(window, icon);
    SDL_FreeSurface(icon);
    return true;
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
    for (int i = 0; i < s_windows.capacity(); ++i)
    {
        SDL_Window *window = s_windows.get(i);
        if (window && SDL_GetWindowID(window) == (Uint32)sdlWindowId)
        {
            return i;
        }
    }
    return -1;
}

