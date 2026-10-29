#pragma once

#include "graphics/renderer.h"

#include <cstdint>

// The software renderer and its textures under the names software_names_nds.h
// gives them, for renderer_nds.cpp and texture_nds.cpp to call with the ids
// the software side numbers its own from zero.

extern "C"
{
    int fried_software_renderer_create(int windowId, bool vsync);
    void fried_software_renderer_destroy(int rendererId);
    bool fried_software_renderer_has_vsync(int rendererId);
    int fried_software_renderer_get_width(int rendererId);
    int fried_software_renderer_get_height(int rendererId);
    void fried_software_renderer_set_draw_color(int rendererId, int r, int g, int b, int a);
    void fried_software_renderer_clear(int rendererId);
    void fried_software_renderer_present(int rendererId);
    void fried_software_renderer_draw_texture(int rendererId, int textureId, float x, float y, float width, float height);
    void fried_software_renderer_draw_texture_ex(int rendererId, int textureId, int srcX, int srcY, int srcWidth, int srcHeight, float x, float y, float width, float height, double angle, int flipMode);
    void fried_software_renderer_fill_rect(int rendererId, float x, float y, float width, float height);
    void fried_software_renderer_draw_rect(int rendererId, float x, float y, float width, float height);
    void fried_software_renderer_fill_triangles(int rendererId, const double *points, const int *argbColors, int triangleCount);

    int fried_software_texture_load(int rendererId, const char *path);
    void fried_software_texture_destroy(int textureId);
    int fried_software_texture_get_width(int textureId);
    int fried_software_texture_get_height(int textureId);
    int fried_software_texture_get_downscale(int textureId);
}

void fried_software_renderer_draw_tinted(int rendererId, int textureId, const FriedQuad *quads, int count, int r, int g, int b, int a);
bool fried_software_renderer_draw_glyphs(int rendererId, int textureId, float x, float y, const FriedGlyphBlit *glyphs, int count, int r, int g, int b, int a);
float fried_software_renderer_get_pixel_scale(int rendererId);
void fried_software_renderer_window_to_logical(int windowId, int x, int y, int &logicalX, int &logicalY);
void fried_software_renderer_touch_to_logical(int windowId, float x, float y, int &logicalX, int &logicalY);

int fried_software_texture_create_blank(int rendererId, int width, int height);
bool fried_software_texture_write_alpha(int textureId, int x, int y, const uint8_t *alpha, int width, int height);

// What the software renderer calls when it is destroyed, with its own id.
void fried_software_font_release_renderer(int rendererId);

// Public ids from this one on are the software side's, offset by it.
constexpr int FRIED_SOFTWARE_ID_BASE = 1 << 12;
