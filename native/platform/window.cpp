#include "platform/window.h"

#include "handle_pool.h"
#include "last_error.h"

#include <SDL.h>
#include <SDL_image.h>

#include <cstdio>

namespace
{
    HandlePool<SDL_Window> s_windows;

    bool displayHasWindow(int displayIndex)
    {
        for (int i = 0; i < s_windows.capacity(); ++i)
        {
            SDL_Window *window = s_windows.get(i);
            if (window && SDL_GetWindowDisplayIndex(window) == displayIndex)
            {
                return true;
            }
        }
        return false;
    }

    int firstDisplayWithoutWindow()
    {
        int displayCount = SDL_GetNumVideoDisplays();
        for (int displayIndex = 0; displayIndex < displayCount; ++displayIndex)
        {
            if (!displayHasWindow(displayIndex))
            {
                return displayIndex;
            }
        }
        return 0;
    }
}

int fried_window_get_max_count()
{
    return FRIED_MAX_WINDOWS;
}

SDL_Window *fried_window_get_sdl(int windowId)
{
    return s_windows.get(windowId);
}

int fried_window_create(const char *title, int width, int height)
{
    if (s_windows.count() >= FRIED_MAX_WINDOWS)
    {
        char message[128];
        std::snprintf(
            message, sizeof(message),
            "This platform shows at most %d window(s) at a time",
            FRIED_MAX_WINDOWS);
        fried_set_last_error(message);
        return -1;
    }

#ifdef __3DS__
    int displayIndex = firstDisplayWithoutWindow();
#else
    int displayIndex = 0;
#endif

#if defined(__vita__) || defined(__SWITCH__) || defined(__3DS__)
    SDL_DisplayMode screen;
    if (SDL_GetDesktopDisplayMode(displayIndex, &screen) != 0)
    {
        fried_capture_sdl_error();
        return -1;
    }
    width = screen.w;
    height = screen.h;
#endif

    SDL_Window *window = SDL_CreateWindow(
        title,
        SDL_WINDOWPOS_CENTERED_DISPLAY(displayIndex), SDL_WINDOWPOS_CENTERED_DISPLAY(displayIndex),
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

