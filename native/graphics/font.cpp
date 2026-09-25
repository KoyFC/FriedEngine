#include "graphics/font.h"

#include "graphics/renderer.h"
#include "graphics/texture.h"

#include <SDL.h>
#include <SDL_ttf.h>
#include <vector>

namespace
{
    std::vector<TTF_Font *> s_fonts;
    std::vector<int> s_freeFontIds;

    TTF_Font *fontAt(int fontId)
    {
        if (fontId < 0 || fontId >= (int)s_fonts.size())
        {
            return nullptr;
        }
        return s_fonts[fontId];
    }
}

int fried_font_load(const char *path, int size)
{
    if (!path || size <= 0)
    {
        return -1;
    }

    TTF_Font *font = TTF_OpenFont(path, size);
    if (!font)
    {
        return -1;
    }

    if (!s_freeFontIds.empty())
    {
        int fontId = s_freeFontIds.back();
        s_freeFontIds.pop_back();
        s_fonts[fontId] = font;
        return fontId;
    }

    s_fonts.push_back(font);
    return (int)(s_fonts.size() - 1);
}

void fried_font_destroy(int fontId)
{
    TTF_Font *font = fontAt(fontId);
    if (!font)
    {
        return;
    }

    TTF_CloseFont(font);
    s_fonts[fontId] = nullptr;
    s_freeFontIds.push_back(fontId);
}

int fried_font_get_line_height(int fontId)
{
    TTF_Font *font = fontAt(fontId);
    if (!font)
    {
        return 0;
    }
    return TTF_FontHeight(font);
}

int fried_font_measure_width(int fontId, const char *text)
{
    TTF_Font *font = fontAt(fontId);
    if (!font || !text)
    {
        return 0;
    }

    int width = 0;
    if (TTF_SizeUTF8(font, text, &width, nullptr) != 0)
    {
        return 0;
    }
    return width;
}

int fried_font_render_text(int fontId, int rendererId, const char *text, int r, int g, int b, int a)
{
    TTF_Font *font = fontAt(fontId);
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!font || !renderer || !text)
    {
        return -1;
    }

    SDL_Color color = {(Uint8)r, (Uint8)g, (Uint8)b, (Uint8)a};
    SDL_Surface *surface = TTF_RenderUTF8_Blended(font, text, color);
    if (!surface)
    {
        return -1;
    }

    SDL_Texture *texture = SDL_CreateTextureFromSurface(renderer, surface);
    SDL_FreeSurface(surface);
    if (!texture)
    {
        return -1;
    }

    return fried_texture_store_sdl(texture);
}
