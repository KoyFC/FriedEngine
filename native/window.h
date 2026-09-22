#pragma once

extern "C"
{
    int fried_window_create(const char *title, int width, int height);
    void fried_window_destroy(int windowId);
    int fried_window_get_width(int windowId);
    int fried_window_get_height(int windowId);
}
