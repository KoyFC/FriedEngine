#pragma once

extern "C"
{
    int fried_font_load(const char *path, int size);
    void fried_font_destroy(int fontId);

    int fried_font_get_line_height(int fontId);
    int fried_font_measure_width(int fontId, const char *text);

    // Stretched to fill width x height, rotated about the centre of that box.
    void fried_font_draw_text(int fontId, int rendererId, const char *text, float x, float y, float width, float height, double angle, int r, int g, int b, int a);
}

void fried_font_release_renderer(int rendererId);
