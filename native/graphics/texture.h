#pragma once

struct SDL_Rect;
struct SDL_Surface;

extern "C"
{
    int fried_texture_load(int rendererId, const char *path);
    void fried_texture_destroy(int textureId);

    int fried_texture_get_width(int textureId);
    int fried_texture_get_height(int textureId);
    // How many times smaller than its source a texture is stored, where the GPU caps its size.
    int fried_texture_get_downscale(int textureId);
}

int fried_texture_create_blank(int rendererId, int width, int height);
bool fried_texture_write(int textureId, int x, int y, struct SDL_Surface *surface, const struct SDL_Rect *sourceRect);

#ifdef __3DS__
#include <citro2d.h>

const C2D_Image *fried_texture_get_citro(int textureId);
#elif defined(TARGET_FXCG50)
#include <cstdint>

// RGB565, the screen's own format, with an alpha channel only when the image
// has a pixel that is not fully opaque.
struct FriedGintTexture
{
    int m_width;
    int m_height;
    uint16_t *m_pixels;
    uint8_t *m_alpha;
};

const FriedGintTexture *fried_texture_get_gint(int textureId);
#else
struct SDL_Texture;

struct SDL_Texture *fried_texture_get_sdl(int textureId);
#endif
