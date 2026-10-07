#include "graphics/font.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/renderer.h"
#include "graphics/texture.h"

#include <SDL.h>
#include <SDL_ttf.h>

#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <vector>

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

    struct GlyphSource
    {
        TTF_Font *m_font;
        int m_ascent;
        std::unordered_map<Uint32, GlyphMetrics> m_metrics;
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
        std::unordered_map<Uint32, SDL_Rect> m_regions;
    };

    struct LoadedFont
    {
        void *m_fileData;
        size_t m_fileSize;
        int m_size;
        int m_lineHeight;
        GlyphSource m_layoutSource;
        std::unordered_map<Uint64, int> m_kerning;
        std::vector<GlyphAtlas> m_atlases;
    };

    struct PlacedGlyph
    {
        Uint32 m_codepoint;
        const GlyphMetrics *m_metrics;
        int m_penX;
    };

    HandlePool<LoadedFont> s_fonts;

    std::vector<PlacedGlyph> s_placedGlyphs;
    std::vector<FriedQuad> s_quads;

    constexpr Uint32 s_replacementCharacter = 0xFFFD;
    constexpr Uint32 s_firstPreloadedCharacter = 0x20;
    constexpr Uint32 s_lastPreloadedCharacter = 0x7E;
    constexpr SDL_Color s_white = {255, 255, 255, 255};

    constexpr int s_glyphSpacing = 1;
    constexpr int s_minAtlasSide = 256;
    constexpr int s_maxAtlasSide = 1024;
    constexpr int s_squareGlyphsPerAtlas = 128;

    Uint32 nextCodepoint(const char *&cursor)
    {
        const unsigned char *bytes = (const unsigned char *)cursor;
        Uint32 lead = bytes[0];
        int length = lead < 0x80 ? 1 : (lead >> 5) == 0x6 ? 2 : (lead >> 4) == 0xE ? 3 : (lead >> 3) == 0x1E ? 4 : 0;
        if (length == 0)
        {
            ++cursor;
            return s_replacementCharacter;
        }

        Uint32 codepoint = length == 1 ? lead : lead & (0x7F >> length);
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

    const GlyphMetrics &metricsOf(GlyphSource &source, Uint32 codepoint)
    {
        auto found = source.m_metrics.find(codepoint);
        if (found != source.m_metrics.end())
        {
            return found->second;
        }

        GlyphMetrics metrics = {};
        int minX = 0;
        int maxX = 0;
        int minY = 0;
        int maxY = 0;
        int advance = 0;
        if (TTF_GlyphMetrics32(source.m_font, codepoint, &minX, &maxX, &minY, &maxY, &advance) == 0)
        {
            metrics = {minX, source.m_ascent - maxY, maxX - minX, maxY - minY, advance};
        }
        return source.m_metrics.emplace(codepoint, metrics).first->second;
    }

    // SDL_ttf caches 256 glyphs by index modulo 256, so asking it every frame
    // reloads any two glyphs of a line that share a slot through FreeType.
    int kerningBetween(LoadedFont &font, Uint32 previous, Uint32 codepoint)
    {
        Uint64 pair = ((Uint64)previous << 32) | codepoint;
        auto found = font.m_kerning.find(pair);
        if (found != font.m_kerning.end())
        {
            return found->second;
        }
        int kerning = TTF_GetFontKerningSizeGlyphs32(font.m_layoutSource.m_font, previous, codepoint);
        return font.m_kerning.emplace(pair, kerning).first->second;
    }

    // A glyph reaching left of the pen shifts the line right, as SDL_ttf does.
    int layOut(LoadedFont &font, const char *text, std::vector<PlacedGlyph> &glyphs, int &originX)
    {
        glyphs.clear();
        int penX = 0;
        int minX = 0;
        int maxX = 0;
        Uint32 previous = 0;
        while (*text)
        {
            Uint32 codepoint = nextCodepoint(text);
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

    bool reserve(GlyphAtlas &atlas, int width, int height, SDL_Rect &region)
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

    bool rasterize(GlyphAtlas &atlas, Uint32 codepoint, const GlyphMetrics &metrics, const SDL_Rect &region)
    {
        SDL_Surface *surface = TTF_RenderGlyph32_Blended(atlas.m_rasterSource.m_font, codepoint, s_white);
        if (!surface)
        {
            fried_capture_sdl_error();
            return false;
        }

        // SDL_ttf pads the bitmap out to the advance and the line, unless it overhangs them.
        SDL_Rect bitmap = {std::max(0, metrics.m_offsetX), std::max(0, metrics.m_offsetY), region.w, region.h};
        SDL_Rect bounds = {0, 0, surface->w, surface->h};
        SDL_Rect visible = {};
        bool isWritten = SDL_IntersectRect(&bitmap, &bounds, &visible) &&
                         fried_texture_write(atlas.m_textureId, region.x, region.y, surface, &visible);
        SDL_FreeSurface(surface);
        return isWritten;
    }

    const SDL_Rect *atlasRegionOf(GlyphAtlas &atlas, Uint32 codepoint, const GlyphMetrics &metrics)
    {
        auto found = atlas.m_regions.find(codepoint);
        if (found == atlas.m_regions.end())
        {
            SDL_Rect region = {};
            bool hasBitmap = metrics.m_width > 0 && metrics.m_height > 0;
            if (!hasBitmap || !reserve(atlas, metrics.m_width, metrics.m_height, region) ||
                !rasterize(atlas, codepoint, metrics, region))
            {
                region = {};
            }
            found = atlas.m_regions.emplace(codepoint, region).first;
        }
        return found->second.w > 0 ? &found->second : nullptr;
    }

    void destroyAtlas(const LoadedFont &font, const GlyphAtlas &atlas)
    {
        fried_texture_destroy(atlas.m_textureId);
        if (atlas.m_rasterSource.m_font != font.m_layoutSource.m_font)
        {
            TTF_CloseFont(atlas.m_rasterSource.m_font);
        }
    }

    int rasterSizeOn(const LoadedFont &font, int rendererId)
    {
        return std::max(1, (int)std::lround(font.m_size * fried_renderer_get_pixel_scale(rendererId)));
    }

    TTF_Font *openAtSize(const LoadedFont &font, int size)
    {
        if (size == font.m_size)
        {
            return font.m_layoutSource.m_font;
        }
        TTF_Font *opened = TTF_OpenFontRW(SDL_RWFromConstMem(font.m_fileData, (int)font.m_fileSize), 1, size);
        if (!opened)
        {
            fried_capture_sdl_error();
        }
        return opened;
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
            destroyAtlas(font, *atlas);
            font.m_atlases.erase(atlas);
            break;
        }

        TTF_Font *rasterFont = openAtSize(font, rasterSize);
        if (!rasterFont)
        {
            return nullptr;
        }
        int side = atlasSideFor(TTF_FontHeight(rasterFont));
        int textureId = fried_texture_create_blank(rendererId, side, side);
        if (textureId < 0)
        {
            if (rasterFont != font.m_layoutSource.m_font)
            {
                TTF_CloseFont(rasterFont);
            }
            return nullptr;
        }
        font.m_atlases.push_back({rendererId, textureId, side, 0, 0, 0, rasterSize, {rasterFont, TTF_FontAscent(rasterFont), {}}, {}});
        GlyphAtlas &atlas = font.m_atlases.back();
        for (Uint32 codepoint = s_firstPreloadedCharacter; codepoint <= s_lastPreloadedCharacter; ++codepoint)
        {
            atlasRegionOf(atlas, codepoint, metricsOf(atlas.m_rasterSource, codepoint));
        }
        return &atlas;
    }
}

int fried_font_load(const char *path, int size)
{
    if (!path || size <= 0)
    {
        fried_set_last_error("No path given, or the size is not positive");
        return -1;
    }

    // FreeType reads the file glyph by glyph, which from a 3DS's SD card costs milliseconds each.
    size_t fileSize = 0;
    void *fileData = SDL_LoadFile(path, &fileSize);
    if (!fileData)
    {
        fried_capture_sdl_error();
        return -1;
    }

    TTF_Font *ttfFont = TTF_OpenFontRW(SDL_RWFromConstMem(fileData, (int)fileSize), 1, size);
    if (!ttfFont)
    {
        fried_capture_sdl_error();
        SDL_free(fileData);
        return -1;
    }

    LoadedFont *font = new LoadedFont();
    font->m_fileData = fileData;
    font->m_fileSize = fileSize;
    font->m_size = size;
    font->m_lineHeight = TTF_FontHeight(ttfFont);
    font->m_layoutSource = {ttfFont, TTF_FontAscent(ttfFont), {}};
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
        destroyAtlas(*font, atlas);
    }
    TTF_CloseFont(font->m_layoutSource.m_font);
    SDL_free(font->m_fileData);
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
                destroyAtlas(*font, *atlas);
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

int fried_font_render_text(int fontId, int rendererId, const char *text, int r, int g, int b, int a)
{
    LoadedFont *font = s_fonts.get(fontId);
    if (!font || !text)
    {
        fried_set_last_error("No such font, or no text given");
        return -1;
    }

    SDL_Color color = {(Uint8)r, (Uint8)g, (Uint8)b, (Uint8)a};
    SDL_Surface *surface = TTF_RenderUTF8_Blended(font->m_layoutSource.m_font, text, color);
    if (!surface)
    {
        fried_capture_sdl_error();
        return -1;
    }

    int textureId = fried_texture_create_from_surface(rendererId, surface);
    SDL_FreeSurface(surface);
    return textureId;
}

void fried_font_draw_text(int fontId, int rendererId, const char *text, int x, int y, int width, int height, double angle, int r, int g, int b, int a)
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

    float scaleX = width / (float)lineWidth;
    float scaleY = height / (float)font->m_lineHeight;
    float rasterToLayout = (float)font->m_size / atlas->m_rasterSize;
    float pivotX = x + width / 2.0f;
    float pivotY = y + height / 2.0f;
    s_quads.clear();
    for (const PlacedGlyph &glyph : s_placedGlyphs)
    {
        const GlyphMetrics &raster = metricsOf(atlas->m_rasterSource, glyph.m_codepoint);
        const SDL_Rect *region = atlasRegionOf(*atlas, glyph.m_codepoint, raster);
        if (!region)
        {
            continue;
        }
        float glyphX = originX + glyph.m_penX + raster.m_offsetX * rasterToLayout;
        s_quads.push_back({
            region->x,
            region->y,
            region->w,
            region->h,
            x + glyphX * scaleX,
            y + raster.m_offsetY * rasterToLayout * scaleY,
            region->w * rasterToLayout * scaleX,
            region->h * rasterToLayout * scaleY,
            (float)angle,
            pivotX,
            pivotY,
        });
    }
    fried_renderer_draw_tinted(rendererId, atlas->m_textureId, s_quads.data(), (int)s_quads.size(), r, g, b, a);
}
