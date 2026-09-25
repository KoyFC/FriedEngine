#pragma once

extern "C"
{
    int fried_window_create(const char *title, int width, int height);
    void fried_window_destroy(int windowId);
    int fried_window_get_width(int windowId);
    int fried_window_get_height(int windowId);
}

int fried_window_find_by_sdl_id(unsigned int sdlWindowId);

// Repaints and presents every live window's surface. Wayland resizes a window
// only once the client commits a buffer at the new size, so a window that never
// presents cannot be resized by the user at all.
extern "C" void fried_window_present_all();
