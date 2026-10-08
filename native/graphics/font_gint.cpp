#include "graphics/font.h"

#include "last_error.h"

// gint has no TrueType rasterizer, and this backend brings none, so no font is
// ever created and every query answers as it does for a destroyed one.

int fried_font_load(const char *, int)
{
    fried_set_last_error("Fonts cannot be loaded on the fx-CG50");
    return -1;
}

void fried_font_destroy(int)
{
}

int fried_font_get_line_height(int)
{
    return 0;
}

int fried_font_measure_width(int, const char *)
{
    return 0;
}

void fried_font_draw_text(int, int, const char *, float, float, float, float, double, int, int, int, int)
{
}

void fried_font_release_renderer(int)
{
}
