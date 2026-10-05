#include "graphics/texture.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/renderer.h"

#include <SDL.h>
#include <SDL_image.h>

namespace
{
    HandlePool<SDL_Texture> s_textures;
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

    return s_textures.store(texture);
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

    return s_textures.store(texture);
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
