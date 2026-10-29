#include "graphics/pixel_font.h"

#include <gint/display.h>

// gint's own font, the one its text renderer draws with.

namespace
{
    const font_t *native(const FriedPixelFont *font)
    {
        return (const font_t *)font->m_native;
    }
}

const FriedPixelFont *fried_pixel_font_get_default()
{
    static FriedPixelFont s_default = [] {
        const font_t *font = dfont_default();
        return FriedPixelFont{font->line_height, font->data_height, font->char_spacing, font};
    }();
    return &s_default;
}

int fried_pixel_font_find_glyph(const FriedPixelFont *font, uint32_t codepoint)
{
    int glyph = dfont_glyph_index(native(font), codepoint);
    return glyph >= 0 ? glyph : dfont_glyph_index(native(font), '?');
}

int fried_pixel_font_get_glyph_width(const FriedPixelFont *font, int glyph)
{
    const font_t *gintFont = native(font);
    return gintFont->prop ? gintFont->glyph_width[glyph] : gintFont->width;
}

// gint's glyphs are rows of bits run together, the first pixel in the
// highest bit, as its own text renderer reads them.
bool fried_pixel_font_is_set(const FriedPixelFont *font, int glyph, int x, int y)
{
    const font_t *gintFont = native(font);
    const uint32_t *data = gintFont->data + dfont_glyph_offset(gintFont, glyph);
    int bit = y * fried_pixel_font_get_glyph_width(font, glyph) + x;
    return (data[bit >> 5] << (bit & 31)) >> 31;
}
