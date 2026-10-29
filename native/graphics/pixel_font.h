#pragma once

#include <cstdint>

// The pixel font a platform carries, which font_software.cpp falls back to
// when a TrueType font is too large to hold in memory. Its glyphs are bits,
// set where they are drawn, all m_dataHeight rows tall.
struct FriedPixelFont
{
    int m_lineHeight;
    int m_dataHeight;
    int m_charSpacing;
    const void *m_native;
};

// Null where the platform carries none.
const FriedPixelFont *fried_pixel_font_get_default();

// The glyph for a codepoint, or for '?' where the font has none; -1 if it has neither.
int fried_pixel_font_find_glyph(const FriedPixelFont *font, uint32_t codepoint);

int fried_pixel_font_get_glyph_width(const FriedPixelFont *font, int glyph);

bool fried_pixel_font_is_set(const FriedPixelFont *font, int glyph, int x, int y);
