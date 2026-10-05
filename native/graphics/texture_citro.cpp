#include "graphics/texture.h"

#include "handle_pool.h"
#include "last_error.h"

#include <SDL.h>
#include <SDL_image.h>

#include <cstring>

namespace
{
    struct CitroTexture
    {
        C3D_Tex tex;
        Tex3DS_SubTexture subtexture;
        C2D_Image image;
    };

    HandlePool<CitroTexture> s_textures;

    constexpr int s_minTextureSide = 8;
    constexpr int s_maxTextureSide = 1024;

    int nextPowerOfTwo(int value)
    {
        int power = s_minTextureSide;
        while (power < value)
        {
            power *= 2;
        }
        return power;
    }

    // The GPU reads textures in 8x8 tiles, each laid out in Morton order.
    int tiledOffset(int x, int y, int texWidth)
    {
        int tileOffset = ((y >> 3) * (texWidth >> 3) + (x >> 3)) << 6;
        int texelInTile = (x & 1) | ((y & 1) << 1) | ((x & 2) << 1) | ((y & 2) << 2) | ((x & 4) << 2) | ((y & 4) << 3);
        return tileOffset + texelInTile;
    }

    // GPU_RGBA8 texels are SDL_PIXELFORMAT_RGBA8888 words, so each one copies as is.
    void copyToTiles(const SDL_Surface *rgbaSurface, C3D_Tex *tex)
    {
        Uint32 *texels = (Uint32 *)tex->data;
        for (int y = 0; y < rgbaSurface->h; ++y)
        {
            const Uint32 *row = (const Uint32 *)((const Uint8 *)rgbaSurface->pixels + y * rgbaSurface->pitch);
            for (int x = 0; x < rgbaSurface->w; ++x)
            {
                texels[tiledOffset(x, y, tex->width)] = row[x];
            }
        }
    }
}

const C2D_Image *fried_texture_get_citro(int textureId)
{
    CitroTexture *texture = s_textures.get(textureId);
    return texture ? &texture->image : nullptr;
}

int fried_texture_create_from_surface(int rendererId, SDL_Surface *surface)
{
    (void)rendererId;
    if (!surface)
    {
        fried_set_last_error("No surface given");
        return -1;
    }
    if (surface->w > s_maxTextureSide || surface->h > s_maxTextureSide)
    {
        fried_set_last_error("The 3DS GPU takes textures of at most 1024 pixels a side");
        return -1;
    }

    SDL_Surface *rgbaSurface = SDL_ConvertSurfaceFormat(surface, SDL_PIXELFORMAT_RGBA8888, 0);
    if (!rgbaSurface)
    {
        fried_capture_sdl_error();
        return -1;
    }

    CitroTexture *texture = new CitroTexture();
    int texWidth = nextPowerOfTwo(rgbaSurface->w);
    int texHeight = nextPowerOfTwo(rgbaSurface->h);
    if (!C3D_TexInit(&texture->tex, texWidth, texHeight, GPU_RGBA8))
    {
        SDL_FreeSurface(rgbaSurface);
        delete texture;
        fried_set_last_error("Out of GPU memory for a texture");
        return -1;
    }

    std::memset(texture->tex.data, 0, texture->tex.size);
    copyToTiles(rgbaSurface, &texture->tex);
    C3D_TexFlush(&texture->tex);
    C3D_TexSetFilter(&texture->tex, GPU_NEAREST, GPU_NEAREST);
    C3D_TexSetWrap(&texture->tex, GPU_CLAMP_TO_EDGE, GPU_CLAMP_TO_EDGE);

    // The GPU's v runs from the bottom of a texture, so the image's top row is v = 1.
    texture->subtexture = {
        (u16)rgbaSurface->w,
        (u16)rgbaSurface->h,
        0.0f,
        1.0f,
        rgbaSurface->w / (float)texWidth,
        1.0f - rgbaSurface->h / (float)texHeight,
    };
    texture->image = {&texture->tex, &texture->subtexture};

    SDL_FreeSurface(rgbaSurface);
    return s_textures.store(texture);
}

int fried_texture_load(int rendererId, const char *path)
{
    if (!path)
    {
        fried_set_last_error("No path given");
        return -1;
    }

    SDL_Surface *surface = IMG_Load(path);
    if (!surface)
    {
        fried_capture_sdl_error();
        return -1;
    }

    int textureId = fried_texture_create_from_surface(rendererId, surface);
    SDL_FreeSurface(surface);
    return textureId;
}

void fried_texture_destroy(int textureId)
{
    CitroTexture *texture = s_textures.release(textureId);
    if (!texture)
    {
        return;
    }
    C3D_TexDelete(&texture->tex);
    delete texture;
}

int fried_texture_get_width(int textureId)
{
    CitroTexture *texture = s_textures.get(textureId);
    return texture ? texture->subtexture.width : 0;
}

int fried_texture_get_height(int textureId)
{
    CitroTexture *texture = s_textures.get(textureId);
    return texture ? texture->subtexture.height : 0;
}
