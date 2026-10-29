#include "graphics/font.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/pixel_font.h"
#include "graphics/renderer.h"
#include "graphics/texture.h"

#include <fcntl.h>
#include <unistd.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <new>
#include <string>
#include <unordered_map>
#include <vector>

// TrueType fonts are rasterized with stb_truetype, laid out and drawn the way
// font.cpp does with SDL_ttf. stb_truetype reads a font in place, so the whole
// file has to fit in memory, which a large one does not on the calculator; it
// then falls back to the platform's own pixel font (graphics/pixel_font.h),
// scaled to a whole multiple of its height near the size asked for.
#define STB_TRUETYPE_IMPLEMENTATION
#include "third_party/stb_truetype.h"

namespace
{
    // ASCII is nearly all a game's text, and looked up glyph by glyph every
    // frame, so it is kept in arrays: a hash table's modulo is a division,
    // which neither the SH4 nor the DS's ARM9 has an instruction for.
    constexpr uint32_t s_asciiCount = 128;

    template <typename T>
    struct AsciiTable
    {
        T m_entries[s_asciiCount];
        bool m_known[s_asciiCount] = {};
    };

    // Offsets are from the pen, at the top of the line.
    struct GlyphMetrics
    {
        int m_offsetX;
        int m_offsetY;
        int m_width;
        int m_height;
        int m_advance;
    };

    // One size of one font: a TrueType face at a pixel size, or a pixel font
    // at a whole scale. Both report the size as m_unit, which is what layout and
    // rasterization sizes are compared by.
    struct GlyphSource
    {
        const stbtt_fontinfo *m_trueType;
        float m_trueTypeScale;
        const FriedPixelFont *m_bitmap;
        int m_bitmapScale;
        float m_unit;
        int m_ascent;
        int m_lineHeight;
        std::unordered_map<uint32_t, GlyphMetrics> m_metrics;
        AsciiTable<GlyphMetrics> m_asciiMetrics;
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
        int m_width;
        int m_height;
        int m_cursorX;
        int m_cursorY;
        int m_rowHeight;
        int m_rasterSize;
        GlyphSource m_rasterSource;
        std::unordered_map<uint32_t, AtlasRegion> m_regions;
        AsciiTable<AtlasRegion> m_asciiRegions;
    };

    struct PlacedGlyph
    {
        uint32_t m_codepoint;
        const GlyphMetrics *m_metrics;
        int m_penX;
    };

    // Most of a game's text is drawn again as it was the frame before, so a
    // line keeps its layout, and its glyphs' places in the atlas once they
    // have been looked up, for as long as it keeps being drawn. A font keeps
    // the lines drawn last, and a new one takes the place of the one drawn
    // longest ago.
    struct CachedLine
    {
        uint32_t m_hash;
        int m_atlasTextureId;
        uint32_t m_lastUse;
        std::string m_text;
        int m_lineWidth;
        int m_originX;
        std::vector<PlacedGlyph> m_glyphs;
        bool m_hasBlits;
        std::vector<FriedGlyphBlit> m_blits;
    };

    constexpr size_t s_maxCachedLines = 64;

    struct LoadedFont
    {
        unsigned char *m_fileData;
        stbtt_fontinfo m_trueType;
        int m_size;
        int m_lineHeight;
        GlyphSource m_layoutSource;
        std::unordered_map<uint64_t, int> m_kerning;
        // Between printable ASCII characters, with s_unknownKerning where it
        // has not been looked up yet.
        std::vector<int8_t> m_printableKerning;
        std::vector<GlyphAtlas> m_atlases;
        std::vector<CachedLine> m_lines;
        uint32_t m_lineClock;
    };

    HandlePool<LoadedFont> s_fonts;

    std::vector<PlacedGlyph> s_placedGlyphs;
    std::vector<FriedQuad> s_quads;
    std::vector<uint8_t> s_coverage;

    constexpr uint32_t s_replacementCharacter = 0xFFFD;
    constexpr uint32_t s_firstPreloadedCharacter = 0x20;
    constexpr uint32_t s_lastPreloadedCharacter = 0x7E;
    constexpr uint32_t s_printableCount = s_lastPreloadedCharacter - s_firstPreloadedCharacter + 1;
    constexpr int8_t s_unknownKerning = INT8_MIN;

    constexpr int s_glyphSpacing = 1;
    constexpr int s_minAtlasSide = 64;
    constexpr int s_maxAtlasSide = 512;
    // Room left below printable ASCII for the characters rasterized later.
    constexpr int s_spareAtlasRowsDivisor = 3;

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
        return {&info, scale, nullptr, 0, (float)size, ascentPixels, ascentPixels - descentPixels, {}, {}};
    }

    // A pixel font is drawn at whole scales only, so it stays sharp.
    GlyphSource bitmapSource(const FriedPixelFont *font, int size)
    {
        int scale = std::max(1, (int)std::lround((float)size / font->m_lineHeight));
        return {nullptr, 0.0f, font, scale, (float)scale, 0, font->m_lineHeight * scale, {}, {}};
    }

    GlyphMetrics measure(GlyphSource &source, uint32_t codepoint)
    {
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
            const FriedPixelFont *font = source.m_bitmap;
            int glyph = fried_pixel_font_find_glyph(font, codepoint);
            if (glyph >= 0)
            {
                int width = fried_pixel_font_get_glyph_width(font, glyph);
                int scale = source.m_bitmapScale;
                metrics = {0, 0, width * scale, font->m_dataHeight * scale, (width + font->m_charSpacing) * scale};
            }
        }
        return metrics;
    }

    const GlyphMetrics &metricsOf(GlyphSource &source, uint32_t codepoint)
    {
        if (codepoint < s_asciiCount)
        {
            AsciiTable<GlyphMetrics> &table = source.m_asciiMetrics;
            if (!table.m_known[codepoint])
            {
                table.m_entries[codepoint] = measure(source, codepoint);
                table.m_known[codepoint] = true;
            }
            return table.m_entries[codepoint];
        }

        auto found = source.m_metrics.find(codepoint);
        if (found != source.m_metrics.end())
        {
            return found->second;
        }
        return source.m_metrics.emplace(codepoint, measure(source, codepoint)).first->second;
    }

    int kerningBetween(LoadedFont &font, uint32_t previous, uint32_t codepoint)
    {
        const GlyphSource &source = font.m_layoutSource;
        if (!source.m_trueType)
        {
            return 0;
        }

        auto kerningFromFont = [&]() {
            return (int)std::lround(stbtt_GetCodepointKernAdvance(source.m_trueType, (int)previous, (int)codepoint) * source.m_trueTypeScale);
        };

        uint32_t first = previous - s_firstPreloadedCharacter;
        uint32_t second = codepoint - s_firstPreloadedCharacter;
        if (first < s_printableCount && second < s_printableCount)
        {
            if (font.m_printableKerning.empty())
            {
                font.m_printableKerning.assign(s_printableCount * s_printableCount, s_unknownKerning);
            }
            int8_t &kerning = font.m_printableKerning[first * s_printableCount + second];
            if (kerning == s_unknownKerning)
            {
                kerning = (int8_t)std::clamp(kerningFromFont(), INT8_MIN + 1, (int)INT8_MAX);
            }
            return kerning;
        }

        uint64_t pair = ((uint64_t)previous << 32) | codepoint;
        auto found = font.m_kerning.find(pair);
        if (found != font.m_kerning.end())
        {
            return found->second;
        }
        return font.m_kerning.emplace(pair, kerningFromFont()).first->second;
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

    // How tall printable ASCII packs at a width, or -1 when a glyph is wider.
    int asciiHeightAt(GlyphSource &source, int width)
    {
        int cursorX = 0, cursorY = 0, rowHeight = 0;
        for (uint32_t codepoint = s_firstPreloadedCharacter; codepoint <= s_lastPreloadedCharacter; ++codepoint)
        {
            const GlyphMetrics &metrics = metricsOf(source, codepoint);
            if (metrics.m_width <= 0 || metrics.m_height <= 0)
            {
                continue;
            }
            if (metrics.m_width > width)
            {
                return -1;
            }
            if (cursorX + metrics.m_width > width)
            {
                cursorX = 0;
                cursorY += rowHeight + s_glyphSpacing;
                rowHeight = 0;
            }
            cursorX += metrics.m_width + s_glyphSpacing;
            rowHeight = std::max(rowHeight, metrics.m_height);
        }
        return cursorY + rowHeight;
    }

    // The smallest power of two each way, and the squarest of those, that
    // printable ASCII fills to all but a third of its height, packed as
    // reserve() packs it. The DS draws its atlases from 256 KB of VRAM, all of
    // which a square sized from the line height alone took for one 18 pixel font.
    void atlasSizeFor(GlyphSource &source, int &atlasWidth, int &atlasHeight)
    {
        atlasWidth = s_maxAtlasSide;
        atlasHeight = s_maxAtlasSide;
        for (int width = s_minAtlasSide; width <= s_maxAtlasSide; width *= 2)
        {
            int asciiHeight = asciiHeightAt(source, width);
            if (asciiHeight < 0)
            {
                continue;
            }
            int height = s_minAtlasSide;
            while (height < asciiHeight + asciiHeight / s_spareAtlasRowsDivisor)
            {
                height *= 2;
            }
            bool smaller = width * height < atlasWidth * atlasHeight;
            bool squarer = width * height == atlasWidth * atlasHeight && std::max(width, height) < std::max(atlasWidth, atlasHeight);
            if (height <= s_maxAtlasSide && (smaller || squarer))
            {
                atlasWidth = width;
                atlasHeight = height;
            }
        }
    }

    bool reserve(GlyphAtlas &atlas, int width, int height, AtlasRegion &region)
    {
        if (atlas.m_cursorX + width > atlas.m_width)
        {
            atlas.m_cursorX = 0;
            atlas.m_cursorY += atlas.m_rowHeight + s_glyphSpacing;
            atlas.m_rowHeight = 0;
        }
        if (width > atlas.m_width || atlas.m_cursorY + height > atlas.m_height)
        {
            return false;
        }

        region = {atlas.m_cursorX, atlas.m_cursorY, width, height};
        atlas.m_cursorX += width + s_glyphSpacing;
        atlas.m_rowHeight = std::max(atlas.m_rowHeight, height);
        return true;
    }

    void rasterizeBitmap(const GlyphSource &source, uint32_t codepoint, const GlyphMetrics &metrics, uint8_t *coverage)
    {
        const FriedPixelFont *font = source.m_bitmap;
        int glyph = fried_pixel_font_find_glyph(font, codepoint);
        int scale = source.m_bitmapScale;
        for (int y = 0; y < metrics.m_height; ++y)
        {
            for (int x = 0; x < metrics.m_width; ++x)
            {
                coverage[y * metrics.m_width + x] = fried_pixel_font_is_set(font, glyph, x / scale, y / scale) ? 255 : 0;
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

    AtlasRegion place(GlyphAtlas &atlas, uint32_t codepoint, const GlyphMetrics &metrics)
    {
        AtlasRegion region = {};
        bool hasBitmap = metrics.m_width > 0 && metrics.m_height > 0;
        if (!hasBitmap || !reserve(atlas, metrics.m_width, metrics.m_height, region) ||
            !rasterize(atlas, codepoint, metrics, region))
        {
            region = {};
        }
        return region;
    }

    const AtlasRegion *atlasRegionOf(GlyphAtlas &atlas, uint32_t codepoint, const GlyphMetrics &metrics)
    {
        const AtlasRegion *region = nullptr;
        if (codepoint < s_asciiCount)
        {
            AsciiTable<AtlasRegion> &table = atlas.m_asciiRegions;
            if (!table.m_known[codepoint])
            {
                table.m_entries[codepoint] = place(atlas, codepoint, metrics);
                table.m_known[codepoint] = true;
            }
            region = &table.m_entries[codepoint];
        }
        else
        {
            auto found = atlas.m_regions.find(codepoint);
            if (found == atlas.m_regions.end())
            {
                found = atlas.m_regions.emplace(codepoint, place(atlas, codepoint, metrics)).first;
            }
            region = &found->second;
        }
        return region->m_width > 0 ? region : nullptr;
    }

    int rasterSizeOn(const LoadedFont &font, int rendererId)
    {
        return std::max(1, (int)std::lround(font.m_size * fried_renderer_get_pixel_scale(rendererId)));
    }

    GlyphSource sourceAtSize(const LoadedFont &font, int size)
    {
        return font.m_layoutSource.m_trueType ? trueTypeSource(font.m_trueType, size) : bitmapSource(font.m_layoutSource.m_bitmap, size);
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
            font.m_lines.clear();
            break;
        }

        GlyphSource rasterSource = sourceAtSize(font, rasterSize);
        int width = 0, height = 0;
        atlasSizeFor(rasterSource, width, height);
        int textureId = fried_texture_create_blank(rendererId, width, height);
        if (textureId < 0)
        {
            return nullptr;
        }
        font.m_atlases.push_back({rendererId, textureId, width, height, 0, 0, 0, rasterSize, rasterSource, {}});
        GlyphAtlas &atlas = font.m_atlases.back();
        for (uint32_t codepoint = s_firstPreloadedCharacter; codepoint <= s_lastPreloadedCharacter; ++codepoint)
        {
            atlasRegionOf(atlas, codepoint, metricsOf(atlas.m_rasterSource, codepoint));
        }
        return &atlas;
    }

    // FNV-1a, which finds a line among the cached ones without comparing
    // every one of them byte by byte.
    uint32_t hashOf(const char *text)
    {
        uint32_t hash = 2166136261u;
        for (const unsigned char *at = (const unsigned char *)text; *at; ++at)
        {
            hash = (hash ^ *at) * 16777619u;
        }
        return hash;
    }

    CachedLine &lineFor(LoadedFont &font, const GlyphAtlas &atlas, const char *text)
    {
        uint32_t hash = hashOf(text);
        uint32_t now = ++font.m_lineClock;
        for (CachedLine &line : font.m_lines)
        {
            if (line.m_hash == hash && line.m_atlasTextureId == atlas.m_textureId && line.m_text == text)
            {
                line.m_lastUse = now;
                return line;
            }
        }

        CachedLine *line = nullptr;
        if (font.m_lines.size() < s_maxCachedLines)
        {
            font.m_lines.emplace_back();
            line = &font.m_lines.back();
        }
        else
        {
            line = &*std::min_element(font.m_lines.begin(), font.m_lines.end(),
                                      [](const CachedLine &a, const CachedLine &b) { return a.m_lastUse < b.m_lastUse; });
        }
        line->m_hash = hash;
        line->m_atlasTextureId = atlas.m_textureId;
        line->m_lastUse = now;
        line->m_text = text;
        line->m_lineWidth = layOut(font, text, line->m_glyphs, line->m_originX);
        line->m_hasBlits = false;
        line->m_blits.clear();
        return *line;
    }

    // One read for the whole file: on the calculator each call into the
    // filesystem is a world switch to the OS and back. A file too big to hold is not an error, only
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
        const FriedPixelFont *pixelFont = fried_pixel_font_get_default();
        if (!pixelFont)
        {
            delete font;
            fried_set_last_error("Not enough memory to read the font");
            return -1;
        }
        font->m_layoutSource = bitmapSource(pixelFont, size);
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
                font->m_lines.clear();
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

    GlyphAtlas *atlas = atlasFor(*font, rendererId);
    if (!atlas)
    {
        return;
    }
    CachedLine &line = lineFor(*font, *atlas, text);
    int lineWidth = line.m_lineWidth;
    int originX = line.m_originX;
    if (lineWidth <= 0)
    {
        return;
    }

    // A line drawn unturned at the size it was laid out and rasterized at
    // needs no transform: its glyphs go to the screen as the atlas holds them.
    if (angle == 0.0 && width == (float)lineWidth && height == (float)font->m_lineHeight && atlas->m_rasterSize == font->m_size)
    {
        if (!line.m_hasBlits)
        {
            for (const PlacedGlyph &glyph : line.m_glyphs)
            {
                const AtlasRegion *region = atlasRegionOf(*atlas, glyph.m_codepoint, *glyph.m_metrics);
                if (region)
                {
                    line.m_blits.push_back({region->m_x, region->m_y, region->m_width, region->m_height,
                                            originX + glyph.m_penX + glyph.m_metrics->m_offsetX, glyph.m_metrics->m_offsetY});
                }
            }
            line.m_hasBlits = true;
        }
        if (fried_renderer_draw_glyphs(rendererId, atlas->m_textureId, x, y, line.m_blits.data(), (int)line.m_blits.size(), r, g, b, a))
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
    for (const PlacedGlyph &glyph : line.m_glyphs)
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
