#pragma once

extern "C"
{
    int fried_renderer_create(int windowId, bool vsync);
    void fried_renderer_destroy(int rendererId);
    bool fried_renderer_has_vsync(int rendererId);

    int fried_renderer_get_width(int rendererId);
    int fried_renderer_get_height(int rendererId);

    void fried_renderer_set_draw_color(int rendererId, int r, int g, int b, int a);
    void fried_renderer_clear(int rendererId);
    void fried_renderer_present(int rendererId);

    void fried_renderer_draw_texture(int rendererId, int textureId, int x, int y, int width, int height);
    void fried_renderer_draw_texture_ex(int rendererId, int textureId, int srcX, int srcY, int srcWidth, int srcHeight, int x, int y, int width, int height, double angle, int flipMode);

    void fried_renderer_fill_rect(int rendererId, int x, int y, int width, int height);
    void fried_renderer_draw_rect(int rendererId, int x, int y, int width, int height);
}

#ifndef __3DS__
struct SDL_Renderer;

struct SDL_Renderer *fried_renderer_get_sdl(int rendererId);
#endif
