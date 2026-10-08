#include "graphics/font.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/renderer.h"
#include "graphics/texture.h"

#include <gint/display.h>

#include <fcntl.h>
#include <unistd.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <new>
#include <unordered_map>
#include <vector>

// TrueType fonts are rasterized with stb_truetype, laid out and drawn the way
// font.cpp does with SDL_ttf. stb_truetype reads a font in place, so the whole
// file has to fit in memory, which a large one does not on the calculator; it
// then falls back to gint's own pixel font, scaled to a whole multiple of its
// height near the size asked for.
#define STB_TRUETYPE_IMPLEMENTATION
#include "third_party/stb_truetype.h"

namespace
{
    // Offsets are from the pen, at the top of the line.
    struct GlyphMetrics
    {
        int m_offsetX;
        int m_offsetY;
        int m_width;
        int m_height;
        int m_advance;
    };

    // One size of one font: a TrueType face at a pixel size, or gint's font at
    // a whole scale. Both report the size as m_unit, which is what layout and
    // rasterization sizes are compared by.
    struct GlyphSource
    {
        const stbtt_fontinfo *m_trueType;
        float m_trueTypeScale;
        const font_t *m_bitmap;
        int m_bitmapScale;
        float m_unit;
        int m_ascent;
        int m_lineHeight;
        std::unordered_map<uint32_t, GlyphMetrics> m_metrics;
    };

    struct AtlasRegion
    {
        int m_x;
        int m_y;
        int m_width;
        int m_height;
    };

    // Rasterized at the size the font covers on screen, which differs from
    // the size the text is laid out at whenever the display scales.
    // A glyph that did not fit keeps an empty region, so it is not retried every frame.
    struct GlyphAtlas
    {
        int m_rendererId;
        int m_textureId;
        int m_side;
        int m_cursorX;
        int m_cursorY;
        int m_rowHeight;
        int m_rasterSize;
        GlyphSource m_rasterSource;
        std::unordered_map<uint32_t, AtlasRegion> m_regions;
    };

    struct LoadedFont
    {
        unsigned char *m_fileData;
        stbtt_fontinfo m_trueType;
        int m_size;
        int m_lineHeight;
        GlyphSource m_layoutSource;
        std::unordered_map<uint64_t, int> m_kerning;
        std::vector<GlyphAtlas> m_atlases;
    };

    struct PlacedGlyph
    {
        uint32_t m_codepoint;
        const GlyphMetrics *m_metrics;
        int m_penX;
    };

    HandlePool<LoadedFont> s_fonts;

    std::vector<PlacedGlyph> s_placedGlyphs;
    std::vector<FriedQuad> s_quads;
    std::vector<FriedGlyphBlit> s_blits;
    std::vector<uint8_t> s_coverage;

    constexpr uint32_t s_replacementCharacter = 0xFFFD;
    constexpr uint32_t s_firstPreloadedCharacter = 0x20;
    constexpr uint32_t s_lastPreloadedCharacter = 0x7E;

    constexpr int s_glyphSpacing = 1;
    constexpr int s_minAtlasSide = 64;
    constexpr int s_maxAtlasSide = 512;
    constexpr int s_squareGlyphsPerAtlas = 128;

    uint32_t nextCodepoint(const char *&cursor)
    {
        const unsigned char *bytes = (const unsigned char *)cursor;
        uint32_t lead = bytes[0];
        int length = lead < 0x80 ? 1 : (lead >> 5) == 0x6 ? 2 : (lead >> 4) == 0xE ? 3 : (lead >> 3) == 0x1E ? 4 : 0;
        if (length == 0)
        {
            ++cursor;
            return s_replacementCharacter;
        }

        uint32_t codepoint = length == 1 ? lead : lead & (0x7F >> length);
        for (int index = 1; index < length; ++index)
        {
            if ((bytes[index] & 0xC0) != 0x80)
            {
                cursor += index;
                return s_replacementCharacter;
            }
            codepoint = (codepoint << 6) | (bytes[index] & 0x3F);
        }
        cursor += length;
        return codepoint;
    }

    // stb_truetype sizes a face by its em, the way SDL_ttf's point size does.
    GlyphSource trueTypeSource(const stbtt_fontinfo &info, int size)
    {
        float scale = stbtt_ScaleForMappingEmToPixels(&info, (float)size);
        int ascent = 0, descent = 0, lineGap = 0;
        stbtt_GetFontVMetrics(&info, &ascent, &descent, &lineGap);
        int ascentPixels = (int)std::ceil(ascent * scale);
        int descentPixels = (int)std::floor(descent * scale);
        return {&info, scale, nullptr, 0, (float)size, ascentPixels, ascentPixels - descentPixels, {}};
    }

    // gint's font is drawn at whole scales only, so it stays sharp.
    GlyphSource bitmapSource(int size)
    {
        const font_t *font = dfont_default();
        int scale = std::max(1, (int)std::lround((float)size / font->line_height));
        return {nullptr, 0.0f, font, scale, (float)scale, 0, font->line_height * scale, {}};
    }

    int bitmapGlyphOf(const font_t *font, uint32_t codepoint)
    {
        int glyph = dfont_glyph_index(font, codepoint);
        return glyph >= 0 ? glyph : dfont_glyph_index(font, '?');
    }

    const GlyphMetrics &metricsOf(GlyphSource &source, uint32_t codepoint)
    {
        auto found = source.m_metrics.find(codepoint);
        if (found != source.m_metrics.end())
        {
            return found->second;
        }

        GlyphMetrics metrics = {};
        if (source.m_trueType)
        {
            int glyph = stbtt_FindGlyphIndex(source.m_trueType, (int)codepoint);
            int advance = 0, leftBearing = 0;
            stbtt_GetGlyphHMetrics(source.m_trueType, glyph, &advance, &leftBearing);
            int x0 = 0, y0 = 0, x1 = 0, y1 = 0;
            stbtt_GetGlyphBitmapBox(source.m_trueType, glyph, source.m_trueTypeScale, source.m_trueTypeScale, &x0, &y0, &x1, &y1);
            metrics = {x0, source.m_ascent + y0, x1 - x0, y1 - y0, (int)std::lround(advance * source.m_trueTypeScale)};
        }
        else
        {
            const font_t *font = source.m_bitmap;
            int glyph = bitmapGlyphOf(font, codepoint);
            if (glyph >= 0)
            {
                int width = font->prop ? font->glyph_width[glyph] : font->width;
                int scale = source.m_bitmapScale;
                metrics = {0, 0, width * scale, font->data_height * scale, (width + font->char_spacing) * scale};
            }
        }
        return source.m_metrics.emplace(codepoint, metrics).first->second;
    }

    int kerningBetween(LoadedFont &font, uint32_t previous, uint32_t codepoint)
    {
        const GlyphSource &source = font.m_layoutSource;
        if (!source.m_trueType)
        {
            return 0;
        }

        uint64_t pair = ((uint64_t)previous << 32) | codepoint;
        auto found = font.m_kerning.find(pair);
        if (found != font.m_kerning.end())
        {
            return found->second;
        }
        int kerning = (int)std::lround(stbtt_GetCodepointKernAdvance(source.m_trueType, (int)previous, (int)codepoint) * source.m_trueTypeScale);
        return font.m_kerning.emplace(pair, kerning).first->second;
    }

    // A glyph reaching left of the pen shifts the line right, as SDL_ttf does.
    int layOut(LoadedFont &font, const char *text, std::vector<PlacedGlyph> &glyphs, int &originX)
    {
        glyphs.clear();
        int penX = 0;
        int minX = 0;
        int maxX = 0;
        uint32_t previous = 0;
        while (*text)
        {
            uint32_t codepoint = nextCodepoint(text);
            const GlyphMetrics &metrics = metricsOf(font.m_layoutSource, codepoint);
            if (previous != 0)
            {
                penX += kerningBetween(font, previous, codepoint);
            }
            glyphs.push_back({codepoint, &metrics, penX});
            minX = std::min(minX, penX + metrics.m_offsetX);
            maxX = std::max({maxX, penX + metrics.m_offsetX + metrics.m_width, penX + metrics.m_advance});
            penX += metrics.m_advance;
            previous = codepoint;
        }
        originX = -minX;
        return maxX - minX;
    }

    int atlasSideFor(int lineHeight)
    {
        int side = s_minAtlasSide;
        while (side < s_maxAtlasSide && side * side < lineHeight * lineHeight * s_squareGlyphsPerAtlas)
        {
            side *= 2;
        }
        return side;
    }

    bool reserve(GlyphAtlas &atlas, int width, int height, AtlasRegion &region)
    {
        if (atlas.m_cursorX + width > atlas.m_side)
        {
            atlas.m_cursorX = 0;
            atlas.m_cursorY += atlas.m_rowHeight + s_glyphSpacing;
            atlas.m_rowHeight = 0;
        }
        if (width > atlas.m_side || atlas.m_cursorY + height > atlas.m_side)
        {
            return false;
        }

        region = {atlas.m_cursorX, atlas.m_cursorY, width, height};
        atlas.m_cursorX += width + s_glyphSpacing;
        atlas.m_rowHeight = std::max(atlas.m_rowHeight, height);
        return true;
    }

    // gint's glyphs are rows of bits run together, the first pixel in the
    // highest bit, as its own text renderer reads them.
    void rasterizeBitmap(const GlyphSource &source, uint32_t codepoint, const GlyphMetrics &metrics, uint8_t *coverage)
    {
        const font_t *font = source.m_bitmap;
        int glyph = bitmapGlyphOf(font, codepoint);
        const uint32_t *data = font->data + dfont_glyph_offset(font, glyph);
        int dataWidth = font->prop ? font->glyph_width[glyph] : font->width;
        int scale = source.m_bitmapScale;
        for (int y = 0; y < metrics.m_height; ++y)
        {
            for (int x = 0; x < metrics.m_width; ++x)
            {
                int bit = (y / scale) * dataWidth + x / scale;
                bool set = (data[bit >> 5] << (bit & 31)) >> 31;
                coverage[y * metrics.m_width + x] = set ? 255 : 0;
            }
        }
    }

    bool rasterize(GlyphAtlas &atlas, uint32_t codepoint, const GlyphMetrics &metrics, const AtlasRegion &region)
    {
        s_coverage.assign((size_t)region.m_width * region.m_height, 0);
        const GlyphSource &source = atlas.m_rasterSource;
        if (source.m_trueType)
        {
            int glyph = stbtt_FindGlyphIndex(source.m_trueType, (int)codepoint);
            stbtt_MakeGlyphBitmap(source.m_trueType, s_coverage.data(), region.m_width, region.m_height, region.m_width,
                                  source.m_trueTypeScale, source.m_trueTypeScale, glyph);
        }
        else
        {
            rasterizeBitmap(source, codepoint, metrics, s_coverage.data());
        }
        return fried_texture_write_alpha(atlas.m_textureId, region.m_x, region.m_y, s_coverage.data(), region.m_width, region.m_height);
    }

    const AtlasRegion *atlasRegionOf(GlyphAtlas &atlas, uint32_t codepoint, const GlyphMetrics &metrics)
    {
        auto found = atlas.m_regions.find(codepoint);
        if (found == atlas.m_regions.end())
        {
            AtlasRegion region = {};
            bool hasBitmap = metrics.m_width > 0 && metrics.m_height > 0;
            if (!hasBitmap || !reserve(atlas, metrics.m_width, metrics.m_height, region) ||
                !rasterize(atlas, codepoint, metrics, region))
            {
                region = {};
            }
            found = atlas.m_regions.emplace(codepoint, region).first;
        }
        return found->second.m_width > 0 ? &found->second : nullptr;
    }

    int rasterSizeOn(const LoadedFont &font, int rendererId)
    {
        return std::max(1, (int)std::lround(font.m_size * fried_renderer_get_pixel_scale(rendererId)));
    }

    GlyphSource sourceAtSize(const LoadedFont &font, int size)
    {
        return font.m_layoutSource.m_trueType ? trueTypeSource(font.m_trueType, size) : bitmapSource(size);
    }

    // ASCII goes in up front so a changing number never rasterizes mid-game.
    GlyphAtlas *atlasFor(LoadedFont &font, int rendererId)
    {
        int rasterSize = rasterSizeOn(font, rendererId);
        for (auto atlas = font.m_atlases.begin(); atlas != font.m_atlases.end(); ++atlas)
        {
            if (atlas->m_rendererId != rendererId)
            {
                continue;
            }
            if (atlas->m_rasterSize == rasterSize)
            {
                return &*atlas;
            }
            fried_texture_destroy(atlas->m_textureId);
            font.m_atlases.erase(atlas);
            break;
        }

        GlyphSource rasterSource = sourceAtSize(font, rasterSize);
        int side = atlasSideFor(rasterSource.m_lineHeight);
        int textureId = fried_texture_create_blank(rendererId, side, side);
        if (textureId < 0)
        {
            return nullptr;
        }
        font.m_atlases.push_back({rendererId, textureId, side, 0, 0, 0, rasterSize, rasterSource, {}});
        GlyphAtlas &atlas = font.m_atlases.back();
        for (uint32_t codepoint = s_firstPreloadedCharacter; codepoint <= s_lastPreloadedCharacter; ++codepoint)
        {
            atlasRegionOf(atlas, codepoint, metricsOf(atlas.m_rasterSource, codepoint));
        }
        return &atlas;
    }

    // One read for the whole file: each call into the filesystem is a world
    // switch to the OS and back. A file too big to hold is not an error, only
    // a reason to fall back, so it reports that apart from failing to read.
    enum class ReadResult
    {
        Read,
        Failed,
        TooBig,
    };

    ReadResult readFile(const char *path, unsigned char *&contents, int &size)
    {
        int fd = open(path, O_RDONLY);
        if (fd < 0)
        {
            fried_set_last_error("No such file");
            return ReadResult::Failed;
        }

        off_t end = lseek(fd, 0, SEEK_END);
        contents = end > 0 ? new (std::nothrow) unsigned char[end] : nullptr;
        if (end > 0 && !contents)
        {
            close(fd);
            return ReadResult::TooBig;
        }

        bool read = contents && lseek(fd, 0, SEEK_SET) == 0 && ::read(fd, contents, end) == end;
        close(fd);
        if (!read)
        {
            delete[] contents;
            contents = nullptr;
            fried_set_last_error("Failed to read the file");
            return ReadResult::Failed;
        }
        size = (int)end;
        return ReadResult::Read;
    }
}

int fried_font_load(const char *path, int size)
{
    if (!path || size <= 0)
    {
        fried_set_last_error("No path given, or the size is not positive");
        return -1;
    }

    unsigned char *fileData = nullptr;
    int fileSize = 0;
    ReadResult result = readFile(path, fileData, fileSize);
    if (result == ReadResult::Failed)
    {
        return -1;
    }

    LoadedFont *font = new (std::nothrow) LoadedFont();
    if (!font)
    {
        delete[] fileData;
        fried_set_last_error("Not enough memory for a font");
        return -1;
    }

    font->m_size = size;
    font->m_fileData = fileData;
    if (fileData)
    {
        int offset = stbtt_GetFontOffsetForIndex(fileData, 0);
        if (offset < 0 || !stbtt_InitFont(&font->m_trueType, fileData, offset))
        {
            delete[] fileData;
            delete font;
            fried_set_last_error("Not a TrueType font");
            return -1;
        }
        font->m_layoutSource = trueTypeSource(font->m_trueType, size);
    }
    else
    {
        font->m_layoutSource = bitmapSource(size);
    }
    font->m_lineHeight = font->m_layoutSource.m_lineHeight;
    return s_fonts.store(font);
}

void fried_font_destroy(int fontId)
{
    LoadedFont *font = s_fonts.release(fontId);
    if (!font)
    {
        return;
    }

    for (const GlyphAtlas &atlas : font->m_atlases)
    {
        fried_texture_destroy(atlas.m_textureId);
    }
    delete[] font->m_fileData;
    delete font;
}

void fried_font_release_renderer(int rendererId)
{
    for (int fontId = 0; fontId < s_fonts.capacity(); ++fontId)
    {
        LoadedFont *font = s_fonts.get(fontId);
        if (!font)
        {
            continue;
        }

        std::vector<GlyphAtlas> &atlases = font->m_atlases;
        for (auto atlas = atlases.begin(); atlas != atlases.end(); ++atlas)
        {
            if (atlas->m_rendererId == rendererId)
            {
                fried_texture_destroy(atlas->m_textureId);
                atlases.erase(atlas);
                break;
            }
        }
    }
}

int fried_font_get_line_height(int fontId)
{
    LoadedFont *font = s_fonts.get(fontId);
    return font ? font->m_lineHeight : 0;
}

// The same layout that draws, so a box sized from it fits exactly.
int fried_font_measure_width(int fontId, const char *text)
{
    LoadedFont *font = s_fonts.get(fontId);
    if (!font || !text)
    {
        return 0;
    }

    int originX = 0;
    return layOut(*font, text, s_placedGlyphs, originX);
}

void fried_font_draw_text(int fontId, int rendererId, const char *text, float x, float y, float width, float height, double angle, int r, int g, int b, int a)
{
    LoadedFont *font = s_fonts.get(fontId);
    if (!font || !text || width <= 0 || height <= 0)
    {
        return;
    }

    int originX = 0;
    int lineWidth = layOut(*font, text, s_placedGlyphs, originX);
    if (lineWidth <= 0)
    {
        return;
    }
    GlyphAtlas *atlas = atlasFor(*font, rendererId);
    if (!atlas)
    {
        return;
    }

    // A line drawn unturned at the size it was laid out and rasterized at
    // needs no transform: its glyphs go to the screen as the atlas holds them.
    if (angle == 0.0 && width == (float)lineWidth && height == (float)font->m_lineHeight && atlas->m_rasterSize == font->m_size)
    {
        s_blits.clear();
        for (const PlacedGlyph &glyph : s_placedGlyphs)
        {
            const AtlasRegion *region = atlasRegionOf(*atlas, glyph.m_codepoint, *glyph.m_metrics);
            if (region)
            {
                s_blits.push_back({region->m_x, region->m_y, region->m_width, region->m_height,
                                   originX + glyph.m_penX + glyph.m_metrics->m_offsetX, glyph.m_metrics->m_offsetY});
            }
        }
        if (fried_renderer_draw_glyphs(rendererId, atlas->m_textureId, x, y, s_blits.data(), (int)s_blits.size(), r, g, b, a))
        {
            return;
        }
    }

    float scaleX = width / (float)lineWidth;
    float scaleY = height / (float)font->m_lineHeight;
    float rasterToLayout = font->m_layoutSource.m_unit / atlas->m_rasterSource.m_unit;
    float pivotX = x + width / 2.0f;
    float pivotY = y + height / 2.0f;
    s_quads.clear();
    for (const PlacedGlyph &glyph : s_placedGlyphs)
    {
        const GlyphMetrics &raster = metricsOf(atlas->m_rasterSource, glyph.m_codepoint);
        const AtlasRegion *region = atlasRegionOf(*atlas, glyph.m_codepoint, raster);
        if (!region)
        {
            continue;
        }
        float glyphX = originX + glyph.m_penX + raster.m_offsetX * rasterToLayout;
        s_quads.push_back({
            region->m_x,
            region->m_y,
            region->m_width,
            region->m_height,
            x + glyphX * scaleX,
            y + raster.m_offsetY * rasterToLayout * scaleY,
            region->m_width * rasterToLayout * scaleX,
            region->m_height * rasterToLayout * scaleY,
            (float)angle,
            pivotX,
            pivotY,
        });
    }
    fried_renderer_draw_tinted(rendererId, atlas->m_textureId, s_quads.data(), (int)s_quads.size(), r, g, b, a);
}
