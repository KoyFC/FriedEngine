#pragma once

struct SDL_Texture;

extern "C"
{
    int fried_texture_load(int rendererId, const char *path);
    void fried_texture_destroy(int textureId);

    int fried_texture_get_width(int textureId);
    int fried_texture_get_height(int textureId);
}

struct SDL_Texture *fried_texture_get_sdl(int textureId);
