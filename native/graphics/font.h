#pragma once

extern "C"
{
    int fried_font_load(const char *path, int size);
    void fried_font_destroy(int fontId);

    int fried_font_get_line_height(int fontId);
    int fried_font_measure_width(int fontId, const char *text);

    int fried_font_render_text(int fontId, int rendererId, const char *text, int r, int g, int b, int a);
}
