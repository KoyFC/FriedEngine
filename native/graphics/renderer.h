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

    // What has been drawn this frame, as RGBA bytes of width x height pixels from the top left. Only the SDL backend has it, for the editor's viewport.
    bool fried_renderer_read_pixels(int rendererId, unsigned char *rgba, int width, int height);

    void fried_renderer_draw_texture(int rendererId, int textureId, float x, float y, float width, float height);
    void fried_renderer_draw_texture_ex(int rendererId, int textureId, int srcX, int srcY, int srcWidth, int srcHeight, float x, float y, float width, float height, double angle, int flipMode);

    void fried_renderer_fill_rect(int rendererId, float x, float y, float width, float height);
    void fried_renderer_draw_rect(int rendererId, float x, float y, float width, float height);

    // A frame's sprites, rectangles and outlines in one call. A record is eight integers and five doubles, in that order in two arrays, and the draw queue's DrawQueue.hx says what each holds. A scaled texture's doubles hold a scale where a texture's hold a size, and its size is its source's times that scale. A camera record sets the camera the records after it are placed by, so a record's numbers are in the world's units until then.
    void fried_renderer_draw_batch(int rendererId, const int *ints, const double *doubles, int count);

    // The batch drawn one call at a time through the functions above, for a renderer with nothing quicker.
    void fried_draw_batch_with_calls(int rendererId, const int *ints, const double *doubles, int count);

    void fried_renderer_fill_triangles(int rendererId, const double *points, const int *argbColors, int triangleCount);
}

// The pivot may lie outside the quad, so a line of glyphs turns as one.
struct FriedQuad
{
    int m_srcX;
    int m_srcY;
    int m_srcWidth;
    int m_srcHeight;
    float m_x;
    float m_y;
    float m_width;
    float m_height;
    float m_angle;
    float m_pivotX;
    float m_pivotY;
};

// Only a white texture tints the same on every backend.
void fried_renderer_draw_tinted(int rendererId, int textureId, const FriedQuad *quads, int count, int r, int g, int b, int a);

#ifdef FRIED_SOFTWARE_FONT
// A glyph drawn at the size it was rasterized at, placed in output pixels
// from the start of its line.
struct FriedGlyphBlit
{
    int m_srcX;
    int m_srcY;
    int m_width;
    int m_height;
    int m_offsetX;
    int m_offsetY;
};

// Draws a line of glyphs from a blank texture with no transform on any of
// them, starting at a logical position. The glyphs are placed in output
// pixels, so they are copied as rasterized however much the display scales.
// A renderer that cannot copy them at that scale draws nothing and returns
// false, for the caller to draw quads.
bool fried_renderer_draw_glyphs(int rendererId, int textureId, float x, float y, const FriedGlyphBlit *glyphs, int count, int r, int g, int b, int a);
#endif

// How many output pixels one logical pixel covers, the smaller axis when they differ.
float fried_renderer_get_pixel_scale(int rendererId);

void fried_renderer_window_to_logical(int windowId, int x, int y, int &logicalX, int &logicalY);

// Takes the touch as SDL reports it, normalized from 0 to 1.
void fried_renderer_touch_to_logical(int windowId, float x, float y, int &logicalX, int &logicalY);

#ifndef __3DS__
struct SDL_Renderer;

struct SDL_Renderer *fried_renderer_get_sdl(int rendererId);
#endif
