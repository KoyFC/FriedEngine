#pragma once

struct SDL_Window;

extern "C"
{
    int fried_window_create(const char *title, int width, int height);
    void fried_window_destroy(int windowId);

    bool fried_window_set_icon(int windowId, const char *path);

    int fried_window_get_width(int windowId);
    int fried_window_get_height(int windowId);
}

int fried_window_find_by_sdl_id(unsigned int sdlWindowId);

struct SDL_Window *fried_window_get_sdl(int windowId);
