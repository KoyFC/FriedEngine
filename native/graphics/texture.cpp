#include "graphics/texture.h"

#include "graphics/renderer.h"

#include <SDL.h>
#include <SDL_image.h>
#include <vector>

namespace
{
    std::vector<SDL_Texture *> s_textures;
    std::vector<int> s_freeTextureIds;
}

int fried_texture_store_sdl(SDL_Texture *texture)
{
    if (!texture)
    {
        return -1;
    }

    if (!s_freeTextureIds.empty())
    {
        int textureId = s_freeTextureIds.back();
        s_freeTextureIds.pop_back();
        s_textures[textureId] = texture;
        return textureId;
    }

    s_textures.push_back(texture);
    return (int)(s_textures.size() - 1);
}

SDL_Texture *fried_texture_get_sdl(int textureId)
{
    if (textureId < 0 || textureId >= (int)s_textures.size())
    {
        return nullptr;
    }
    return s_textures[textureId];
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
    SDL_Texture *texture = fried_texture_get_sdl(textureId);
    if (!texture)
    {
        return;
    }
    SDL_DestroyTexture(texture);
    s_textures[textureId] = nullptr;
    s_freeTextureIds.push_back(textureId);
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
