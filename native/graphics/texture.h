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
#elif defined(__NDS__)
// What the renderer needs to draw a texture: its videoGL name, its size in the
// source's pixels, and the power of two sizes it is stored at. A translucent
// one has coverage that blends, which a blank texture's always does.
struct FriedNdsTexture
{
    int m_name;
    int m_width;
    int m_height;
    int m_downscale;
    int m_textureWidth;
    int m_textureHeight;
    bool m_translucent;
};

const FriedNdsTexture *fried_texture_get_nds(int textureId);

// Copies what fried_texture_write_alpha() changed into VRAM, waiting for the
// vertical blank first when there is any.
void fried_texture_write_pending();
#elif !defined(FRIED_SOFTWARE_RENDERER)
struct SDL_Texture;

struct SDL_Texture *fried_texture_get_sdl(int textureId);
#endif

#ifdef FRIED_SOFTWARE_RENDERER
#include <cstdint>

// The screen's own pixel format, with an alpha channel only when the image
// has a pixel that is not fully opaque. A texture made blank has no colours at
// all, only alpha, and draws white: what a glyph atlas needs, at a third of
// the memory.
struct FriedSoftwareTexture
{
    int m_width;
    int m_height;
    uint16_t *m_pixels;
    uint8_t *m_alpha;
};

const FriedSoftwareTexture *fried_texture_get_software(int textureId);

// Goes up whenever a texture is loaded, destroyed or written to, so a frame
// drawn from the same commands as the last one can still tell it would not
// look the same.
int fried_texture_get_software_generation();
#endif

#ifdef FRIED_SOFTWARE_FONT
#include <cstdint>

// Copies coverage into a blank texture's alpha, as fried_texture_write() does
// a surface elsewhere.
bool fried_texture_write_alpha(int textureId, int x, int y, const uint8_t *alpha, int width, int height);
#endif
