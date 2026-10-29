#include "graphics/pixel_font.h"

// The DS carries no pixel font the engine draws with, so a TrueType font too
// large for memory fails to load rather than falling back.

const FriedPixelFont *fried_pixel_font_get_default()
{
    return nullptr;
}

int fried_pixel_font_find_glyph(const FriedPixelFont *, uint32_t)
{
    return -1;
}

int fried_pixel_font_get_glyph_width(const FriedPixelFont *, int)
{
    return 0;
}

bool fried_pixel_font_is_set(const FriedPixelFont *, int, int, int)
{
    return false;
}
