#pragma once

struct SDL_Surface;

extern "C"
{
    int fried_texture_load(int rendererId, const char *path);
    void fried_texture_destroy(int textureId);

    int fried_texture_get_width(int textureId);
    int fried_texture_get_height(int textureId);
}

// The surface stays the caller's.
int fried_texture_create_from_surface(int rendererId, struct SDL_Surface *surface);

#ifdef __3DS__
#include <citro2d.h>

const C2D_Image *fried_texture_get_citro(int textureId);
#else
struct SDL_Texture;

struct SDL_Texture *fried_texture_get_sdl(int textureId);
#endif
