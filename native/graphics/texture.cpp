#include "graphics/texture.h"

#include "handle_pool.h"
#include "graphics/renderer.h"

#include <SDL.h>
#include <SDL_image.h>

namespace
{
    HandlePool<SDL_Texture> s_textures;
}

int fried_texture_store_sdl(SDL_Texture *texture)
{
    return s_textures.store(texture);
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
        return -1;
    }

    SDL_Texture *texture = IMG_LoadTexture(renderer, path);
    if (!texture)
    {
        return -1;
    }

    return fried_texture_store_sdl(texture);
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
