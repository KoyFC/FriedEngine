#include "graphics/texture.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/display.h"

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
        int downscale;
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

    int downscaleToFit(int width, int height)
    {
        int downscale = 1;
        while (width > s_maxTextureSide * downscale || height > s_maxTextureSide * downscale)
        {
            downscale *= 2;
        }
        return downscale;
    }

    // Each texel is the average of the block of pixels it replaces, channel by
    // channel, so detail thins out evenly rather than whole rows going missing.
    SDL_Surface *downscaled(const SDL_Surface *rgbaSurface, int downscale)
    {
        int width = (rgbaSurface->w + downscale - 1) / downscale;
        int height = (rgbaSurface->h + downscale - 1) / downscale;
        SDL_Surface *result = SDL_CreateRGBSurfaceWithFormat(0, width, height, 32, SDL_PIXELFORMAT_RGBA8888);
        if (!result)
        {
            return nullptr;
        }

        for (int y = 0; y < height; ++y)
        {
            Uint32 *resultRow = (Uint32 *)((Uint8 *)result->pixels + y * result->pitch);
            for (int x = 0; x < width; ++x)
            {
                Uint32 sums[4] = {};
                Uint32 count = 0;
                for (int sourceY = y * downscale; sourceY < (y + 1) * downscale && sourceY < rgbaSurface->h; ++sourceY)
                {
                    const Uint8 *sourceRow = (const Uint8 *)rgbaSurface->pixels + sourceY * rgbaSurface->pitch;
                    for (int sourceX = x * downscale; sourceX < (x + 1) * downscale && sourceX < rgbaSurface->w; ++sourceX)
                    {
                        const Uint8 *channels = sourceRow + sourceX * 4;
                        for (int channel = 0; channel < 4; ++channel)
                        {
                            sums[channel] += channels[channel];
                        }
                        ++count;
                    }
                }

                Uint8 *channels = (Uint8 *)&resultRow[x];
                for (int channel = 0; channel < 4; ++channel)
                {
                    channels[channel] = (Uint8)(sums[channel] / count);
                }
            }
        }
        return result;
    }

    // The GPU reads textures in 8x8 tiles, each laid out in Morton order.
    int tiledOffset(int x, int y, int texWidth)
    {
        int tileOffset = ((y >> 3) * (texWidth >> 3) + (x >> 3)) << 6;
        int texelInTile = (x & 1) | ((y & 1) << 1) | ((x & 2) << 1) | ((y & 2) << 2) | ((x & 4) << 2) | ((y & 4) << 3);
        return tileOffset + texelInTile;
    }

    // GPU_RGBA8 texels are SDL_PIXELFORMAT_RGBA8888 words, so each one copies as is.
    void copyToTiles(const SDL_Surface *rgbaSurface, const SDL_Rect &source, int x, int y, C3D_Tex *tex)
    {
        Uint32 *texels = (Uint32 *)tex->data;
        for (int row = 0; row < source.h; ++row)
        {
            const Uint32 *pixels = (const Uint32 *)((const Uint8 *)rgbaSurface->pixels + (source.y + row) * rgbaSurface->pitch) + source.x;
            for (int column = 0; column < source.w; ++column)
            {
                texels[tiledOffset(x + column, y + row, tex->width)] = pixels[column];
            }
        }
    }

    // Each row of tiles is contiguous in memory.
    void flushTileRows(C3D_Tex *tex, int y, int height)
    {
        int bytesPerTileRow = tex->width * 8 * (int)sizeof(Uint32);
        int firstRow = y / 8;
        int lastRow = (y + height - 1) / 8;
        GSPGPU_FlushDataCache((u8 *)tex->data + firstRow * bytesPerTileRow, (lastRow - firstRow + 1) * bytesPerTileRow);
    }

    CitroTexture *newTexture(int width, int height)
    {
        CitroTexture *texture = new CitroTexture();
        int texWidth = nextPowerOfTwo(width);
        int texHeight = nextPowerOfTwo(height);
        if (!C3D_TexInit(&texture->tex, texWidth, texHeight, GPU_RGBA8))
        {
            delete texture;
            fried_set_last_error("Out of GPU memory for a texture");
            return nullptr;
        }

        std::memset(texture->tex.data, 0, texture->tex.size);
        GPU_TEXTURE_FILTER_PARAM filter = fried_display_filters_linearly() ? GPU_LINEAR : GPU_NEAREST;
        C3D_TexSetFilter(&texture->tex, filter, filter);
        C3D_TexSetWrap(&texture->tex, GPU_CLAMP_TO_EDGE, GPU_CLAMP_TO_EDGE);

        // The GPU's v runs from the bottom of a texture, so the image's top row is v = 1.
        texture->subtexture = {
            (u16)width,
            (u16)height,
            0.0f,
            1.0f,
            width / (float)texWidth,
            1.0f - height / (float)texHeight,
        };
        texture->image = {&texture->tex, &texture->subtexture};
        texture->downscale = 1;
        return texture;
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
    SDL_Surface *rgbaSurface = SDL_ConvertSurfaceFormat(surface, SDL_PIXELFORMAT_RGBA8888, 0);
    if (!rgbaSurface)
    {
        fried_capture_sdl_error();
        return -1;
    }

    int downscale = downscaleToFit(rgbaSurface->w, rgbaSurface->h);
    if (downscale > 1)
    {
        SDL_Surface *fitted = downscaled(rgbaSurface, downscale);
        SDL_FreeSurface(rgbaSurface);
        if (!fitted)
        {
            fried_capture_sdl_error();
            return -1;
        }
        rgbaSurface = fitted;
    }

    CitroTexture *texture = newTexture(rgbaSurface->w, rgbaSurface->h);
    if (!texture)
    {
        SDL_FreeSurface(rgbaSurface);
        return -1;
    }

    copyToTiles(rgbaSurface, {0, 0, rgbaSurface->w, rgbaSurface->h}, 0, 0, &texture->tex);
    C3D_TexFlush(&texture->tex);

    // The size stays the source's, so a downscaled texture still draws and measures as it.
    texture->subtexture.width = (u16)surface->w;
    texture->subtexture.height = (u16)surface->h;
    texture->downscale = downscale;

    SDL_FreeSurface(rgbaSurface);
    return s_textures.store(texture);
}

int fried_texture_create_blank(int rendererId, int width, int height)
{
    (void)rendererId;
    if (width > s_maxTextureSide || height > s_maxTextureSide)
    {
        fried_set_last_error("Larger than the GPU takes");
        return -1;
    }

    CitroTexture *texture = newTexture(width, height);
    if (!texture)
    {
        return -1;
    }
    C3D_TexFlush(&texture->tex);
    return s_textures.store(texture);
}

bool fried_texture_write(int textureId, int x, int y, SDL_Surface *surface, const SDL_Rect *sourceRect)
{
    CitroTexture *texture = s_textures.get(textureId);
    if (!texture || !surface || !sourceRect)
    {
        fried_set_last_error("No such texture, or no surface given");
        return false;
    }
    if (texture->downscale != 1 || x < 0 || y < 0 || x + sourceRect->w > texture->subtexture.width || y + sourceRect->h > texture->subtexture.height)
    {
        fried_set_last_error("The region does not fit the texture");
        return false;
    }

    SDL_Surface *rgbaSurface = SDL_ConvertSurfaceFormat(surface, SDL_PIXELFORMAT_RGBA8888, 0);
    if (!rgbaSurface)
    {
        fried_capture_sdl_error();
        return false;
    }
    copyToTiles(rgbaSurface, *sourceRect, x, y, &texture->tex);
    SDL_FreeSurface(rgbaSurface);
    if (sourceRect->h > 0)
    {
        flushTileRows(&texture->tex, y, sourceRect->h);
    }
    return true;
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

int fried_texture_get_downscale(int textureId)
{
    CitroTexture *texture = s_textures.get(textureId);
    return texture ? texture->downscale : 0;
}
