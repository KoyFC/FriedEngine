#pragma once

// How many windows the platform can show at once. A console's screens are
// fixed hardware, so this is a property of the platform and not a choice the
// game makes. On the 3DS each screen is a window, the top one opened first.
#ifdef __3DS__
#define FRIED_MAX_WINDOWS 2
#else
#define FRIED_MAX_WINDOWS 1
#endif

struct SDL_Window;

extern "C"
{
    int fried_window_get_max_count();

    int fried_window_create(const char *title, int width, int height);
    void fried_window_destroy(int windowId);

    bool fried_window_set_icon(int windowId, const char *path);

    int fried_window_get_width(int windowId);
    int fried_window_get_height(int windowId);
}

int fried_window_find_by_sdl_id(unsigned int sdlWindowId);

struct SDL_Window *fried_window_get_sdl(int windowId);
