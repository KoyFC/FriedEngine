#include "graphics/texture.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/display.h"
#include "graphics/renderer.h"

#include <SDL.h>
#include <SDL_image.h>

#include <vector>

namespace
{
    HandlePool<SDL_Texture> s_textures;

    int storeFiltered(SDL_Texture *texture)
    {
        SDL_SetTextureScaleMode(texture, fried_display_filters_linearly() ? SDL_ScaleModeLinear : SDL_ScaleModeNearest);
        return s_textures.store(texture);
    }
}

SDL_Texture *fried_texture_get_sdl(int textureId)
{
    return s_textures.get(textureId);
}

int fried_texture_load(int rendererId, const char *path)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer || !path)
    {
        fried_set_last_error("No such renderer, or no path given");
        return -1;
    }

    SDL_Texture *texture = IMG_LoadTexture(renderer, path);
    if (!texture)
    {
        fried_capture_sdl_error();
        return -1;
    }

    return storeFiltered(texture);
}

int fried_texture_create_from_surface(int rendererId, SDL_Surface *surface)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer || !surface)
    {
        fried_set_last_error("No such renderer, or no surface given");
        return -1;
    }

    SDL_Texture *texture = SDL_CreateTextureFromSurface(renderer, surface);
    if (!texture)
    {
        fried_capture_sdl_error();
        return -1;
    }

    return storeFiltered(texture);
}

int fried_texture_create_blank(int rendererId, int width, int height)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        fried_set_last_error("No such renderer");
        return -1;
    }

    SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STATIC, width, height);
    if (!texture)
    {
        fried_capture_sdl_error();
        return -1;
    }

    // SDL leaves a new texture's contents undefined.
    std::vector<Uint32> transparent((size_t)width * height, 0);
    if (SDL_UpdateTexture(texture, nullptr, transparent.data(), width * (int)sizeof(Uint32)) != 0)
    {
        fried_capture_sdl_error();
        SDL_DestroyTexture(texture);
        return -1;
    }
    SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND);
    return storeFiltered(texture);
}

bool fried_texture_write(int textureId, int x, int y, SDL_Surface *surface, const SDL_Rect *sourceRect)
{
    SDL_Texture *texture = fried_texture_get_sdl(textureId);
    if (!texture || !surface || !sourceRect)
    {
        fried_set_last_error("No such texture, or no surface given");
        return false;
    }

    Uint32 format = 0;
    SDL_QueryTexture(texture, &format, nullptr, nullptr, nullptr);
    SDL_Surface *converted = SDL_ConvertSurfaceFormat(surface, format, 0);
    if (!converted)
    {
        fried_capture_sdl_error();
        return false;
    }

    const Uint8 *firstPixel = (const Uint8 *)converted->pixels + sourceRect->y * converted->pitch + sourceRect->x * converted->format->BytesPerPixel;
    SDL_Rect destination = {x, y, sourceRect->w, sourceRect->h};
    bool isWritten = SDL_UpdateTexture(texture, &destination, firstPixel, converted->pitch) == 0;
    if (!isWritten)
    {
        fried_capture_sdl_error();
    }
    SDL_FreeSurface(converted);
    return isWritten;
}

void fried_texture_destroy(int textureId)
{
    SDL_Texture *texture = s_textures.release(textureId);
    if (!texture)
    {
        return;
    }
    SDL_DestroyTexture(texture);
}

int fried_texture_get_width(int textureId)
{
    SDL_Texture *texture = fried_texture_get_sdl(textureId);
    if (!texture)
    {
        return 0;
    }
    int width = 0;
    SDL_QueryTexture(texture, nullptr, nullptr, &width, nullptr);
    return width;
}

int fried_texture_get_height(int textureId)
{
    SDL_Texture *texture = fried_texture_get_sdl(textureId);
    if (!texture)
    {
        return 0;
    }
    int height = 0;
    SDL_QueryTexture(texture, nullptr, nullptr, nullptr, &height);
    return height;
}

int fried_texture_get_downscale(int textureId)
{
    return fried_texture_get_sdl(textureId) ? 1 : 0;
}
