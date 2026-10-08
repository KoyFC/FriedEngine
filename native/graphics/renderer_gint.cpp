#include "graphics/renderer.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/display.h"
#include "graphics/font.h"
#include "graphics/texture.h"
#include "platform/window.h"

#include <gint/display.h>

#include <algorithm>
#include <cmath>
#include <cstdint>

// gint draws into a 396x224 RGB565 frame in memory, which dupdate() sends to
// the screen. Everything here is drawn into that frame by the CPU, through
// the same display layout the other backends hand their GPU.

namespace
{
    struct Renderer
    {
        int m_windowId;
        int m_r;
        int m_g;
        int m_b;
        int m_a;
    };

    HandlePool<Renderer> s_renderers;

    // Output pixels, edges included on the left and top and excluded on the
    // right and bottom.
    struct PixelRect
    {
        int m_left;
        int m_top;
        int m_right;
        int m_bottom;
    };

    FriedDisplayLayout layout()
    {
        return fried_display_layout(DWIDTH, DHEIGHT);
    }

    uint16_t toRgb565(int r, int g, int b)
    {
        return (uint16_t)(((r & 0xf8) << 8) | ((g & 0xfc) << 3) | (b >> 3));
    }

    // Each edge goes to the nearest output pixel, as fried_display_snap() does
    // for the other backends, and the result is cut to the viewport.
    PixelRect toPixels(const FriedDisplayLayout &layout, float x, float y, float width, float height)
    {
        PixelRect rect = {
            layout.m_viewportX + (int)std::lround(x * layout.m_scaleX),
            layout.m_viewportY + (int)std::lround(y * layout.m_scaleY),
            layout.m_viewportX + (int)std::lround((x + width) * layout.m_scaleX),
            layout.m_viewportY + (int)std::lround((y + height) * layout.m_scaleY),
        };
        rect.m_left = std::max(rect.m_left, layout.m_viewportX);
        rect.m_top = std::max(rect.m_top, layout.m_viewportY);
        rect.m_right = std::min(rect.m_right, layout.m_viewportX + layout.m_viewportWidth);
        rect.m_bottom = std::min(rect.m_bottom, layout.m_viewportY + layout.m_viewportHeight);
        return rect;
    }

    // x / 255 for x up to 255 * 255, exactly, without the division the SH4
    // can only do in software.
    int divideBy255(int x)
    {
        return (x + 1 + (x >> 8)) >> 8;
    }

    // Blending spreads a colour's three fields apart in 32 bits, green high and
    // red and blue low, so one multiplication by a 5-bit alpha blends all three
    // with room for each to carry: an SH4 multiplication takes several cycles
    // to come back, and three of them per pixel made a translucent rectangle
    // the size of the screen cost around 90 ms. Against blending each channel
    // exactly, no channel is ever off by more than one step.
    constexpr uint32_t s_spreadMask = 0x07E0F81F;

    __attribute__((always_inline)) inline uint32_t spread(uint16_t color)
    {
        return (color | ((uint32_t)color << 16)) & s_spreadMask;
    }

    __attribute__((always_inline)) inline uint16_t pack(uint32_t spreadColor)
    {
        return (uint16_t)((spreadColor & 0xF81F) | (spreadColor >> 16));
    }

    // From 0..255 to the 0..32 the blend takes.
    __attribute__((always_inline)) inline int toBlendAlpha(int alpha)
    {
        return (alpha + 4) >> 3;
    }

    __attribute__((always_inline)) inline void blendPixel(uint16_t &pixel, uint32_t source, int blendAlpha)
    {
        uint32_t destination = spread(pixel);
        pixel = pack(((((source - destination) * blendAlpha) >> 5) + destination) & s_spreadMask);
    }

    void fillPixels(const PixelRect &rect, const Renderer &renderer)
    {
        if (rect.m_left >= rect.m_right || rect.m_top >= rect.m_bottom || renderer.m_a == 0)
        {
            return;
        }

        uint16_t color = toRgb565(renderer.m_r, renderer.m_g, renderer.m_b);
        int blendAlpha = toBlendAlpha(renderer.m_a);
        if (blendAlpha == 32)
        {
            drect(rect.m_left, rect.m_top, rect.m_right - 1, rect.m_bottom - 1, color);
            return;
        }

        uint32_t source = spread(color);
        for (int y = rect.m_top; y < rect.m_bottom; ++y)
        {
            uint16_t *row = gint_vram + y * DWIDTH;
            for (int x = rect.m_left; x < rect.m_right; ++x)
            {
                blendPixel(row[x], source, blendAlpha);
            }
        }
    }

    int clampToPixelInside(int value, int size)
    {
        return std::clamp(value, 0, std::max(0, size - 1));
    }

    constexpr int s_flipHorizontal = 1;
    constexpr int s_flipVertical = 2;

    struct TexturedQuad
    {
        int m_srcX;
        int m_srcY;
        int m_srcWidth;
        int m_srcHeight;
        float m_x;
        float m_y;
        float m_width;
        float m_height;
        double m_angle;
        bool m_hasPivot;
        float m_pivotX;
        float m_pivotY;
        int m_flip;
    };

    // Each screen pixel in the quad's bounds is mapped back through the
    // rotation and the scale to the texel it shows, nearest first. The steps
    // from one pixel to the next are in 16.16 fixed point, since the SH4 has
    // no floating point unit.
    void drawQuad(const FriedGintTexture &texture, const TexturedQuad &quad, int r, int g, int b, int a)
    {
        int srcX = std::max(quad.m_srcX, 0);
        int srcY = std::max(quad.m_srcY, 0);
        int srcWidth = std::min(quad.m_srcX + quad.m_srcWidth, texture.m_width) - srcX;
        int srcHeight = std::min(quad.m_srcY + quad.m_srcHeight, texture.m_height) - srcY;
        if (srcWidth <= 0 || srcHeight <= 0 || a == 0)
        {
            return;
        }

        FriedDisplayLayout current = layout();
        float left = current.m_viewportX + std::round(quad.m_x * current.m_scaleX);
        float top = current.m_viewportY + std::round(quad.m_y * current.m_scaleY);
        float right = current.m_viewportX + std::round((quad.m_x + quad.m_width) * current.m_scaleX);
        float bottom = current.m_viewportY + std::round((quad.m_y + quad.m_height) * current.m_scaleY);
        float width = right - left;
        float height = bottom - top;
        if (width <= 0.0f || height <= 0.0f)
        {
            return;
        }

        float pivotX = quad.m_hasPivot ? current.m_viewportX + quad.m_pivotX * current.m_scaleX : (left + right) / 2.0f;
        float pivotY = quad.m_hasPivot ? current.m_viewportY + quad.m_pivotY * current.m_scaleY : (top + bottom) / 2.0f;
        // Most quads are not turned, and the trigonometry is emulated in software.
        float cosine = 1.0f;
        float sine = 0.0f;
        if (quad.m_angle != 0.0)
        {
            double radians = quad.m_angle * 3.14159265358979323846 / 180.0;
            cosine = (float)std::cos(radians);
            sine = (float)std::sin(radians);
        }

        // The bounds of the turned quad, cut to the viewport.
        float cornersX[4] = {left, right, left, right};
        float cornersY[4] = {top, top, bottom, bottom};
        float minX = 1e9f, minY = 1e9f, maxX = -1e9f, maxY = -1e9f;
        for (int corner = 0; corner < 4; ++corner)
        {
            float offsetX = cornersX[corner] - pivotX;
            float offsetY = cornersY[corner] - pivotY;
            float turnedX = pivotX + cosine * offsetX - sine * offsetY;
            float turnedY = pivotY + sine * offsetX + cosine * offsetY;
            minX = std::min(minX, turnedX);
            maxX = std::max(maxX, turnedX);
            minY = std::min(minY, turnedY);
            maxY = std::max(maxY, turnedY);
        }
        int startX = std::max((int)std::floor(minX), current.m_viewportX);
        int startY = std::max((int)std::floor(minY), current.m_viewportY);
        int endX = std::min((int)std::ceil(maxX), current.m_viewportX + current.m_viewportWidth);
        int endY = std::min((int)std::ceil(maxY), current.m_viewportY + current.m_viewportHeight);
        if (startX >= endX || startY >= endY)
        {
            return;
        }

        // The texel under a pixel's centre, turned back by the angle and
        // scaled from the quad to the source region.
        float scaleU = srcWidth / width;
        float scaleV = srcHeight / height;
        float centreX = startX + 0.5f - pivotX;
        float centreY = startY + 0.5f - pivotY;
        float u = (cosine * centreX + sine * centreY + pivotX - left) * scaleU;
        float v = (-sine * centreX + cosine * centreY + pivotY - top) * scaleV;

        constexpr float s_one = 65536.0f;
        int32_t rowU = (int32_t)(u * s_one);
        int32_t rowV = (int32_t)(v * s_one);
        int32_t stepUAcross = (int32_t)(cosine * scaleU * s_one);
        int32_t stepVAcross = (int32_t)(-sine * scaleV * s_one);
        int32_t stepUDown = (int32_t)(sine * scaleU * s_one);
        int32_t stepVDown = (int32_t)(cosine * scaleV * s_one);
        uint32_t limitU = (uint32_t)srcWidth << 16;
        uint32_t limitV = (uint32_t)srcHeight << 16;

        // A blank texture is white, so tinted it is one colour throughout.
        bool tinted = r != 255 || g != 255 || b != 255;
        uint16_t tint = toRgb565(r, g, b);
        uint32_t spreadTint = spread(tint);
        bool flipX = quad.m_flip & s_flipHorizontal;
        bool flipY = quad.m_flip & s_flipVertical;

        for (int y = startY; y < endY; ++y)
        {
            uint16_t *row = gint_vram + y * DWIDTH;
            int32_t texelU = rowU;
            int32_t texelV = rowV;
            for (int x = startX; x < endX; ++x, texelU += stepUAcross, texelV += stepVAcross)
            {
                if ((uint32_t)texelU >= limitU || (uint32_t)texelV >= limitV)
                {
                    continue;
                }

                int column = texelU >> 16;
                int line = texelV >> 16;
                if (flipX)
                {
                    column = srcWidth - 1 - column;
                }
                if (flipY)
                {
                    line = srcHeight - 1 - line;
                }
                int index = (srcY + line) * texture.m_width + srcX + column;

                int alpha = texture.m_alpha ? divideBy255(texture.m_alpha[index] * a) : a;
                if (alpha == 0)
                {
                    continue;
                }

                uint16_t color;
                if (!texture.m_pixels)
                {
                    color = tint;
                }
                else if (tinted)
                {
                    uint16_t texel = texture.m_pixels[index];
                    color = toRgb565(
                        divideBy255(((texel >> 8) & 0xf8) * r),
                        divideBy255(((texel >> 3) & 0xfc) * g),
                        divideBy255(((texel << 3) & 0xf8) * b));
                }
                else
                {
                    color = texture.m_pixels[index];
                }

                int blendAlpha = toBlendAlpha(alpha);
                if (blendAlpha == 32)
                {
                    row[x] = color;
                }
                else if (blendAlpha > 0)
                {
                    blendPixel(row[x], texture.m_pixels ? spread(color) : spreadTint, blendAlpha);
                }
            }
            rowU += stepUDown;
            rowV += stepVDown;
        }
    }
}

int fried_renderer_create(int windowId, bool)
{
    if (fried_window_get_width(windowId) <= 0)
    {
        fried_set_last_error("No such window");
        return -1;
    }
    return s_renderers.store(new Renderer{windowId, 0, 0, 0, 255});
}

void fried_renderer_destroy(int rendererId)
{
    if (!s_renderers.get(rendererId))
    {
        return;
    }
    fried_font_release_renderer(rendererId);
    delete s_renderers.release(rendererId);
}

// dupdate() sends the frame as soon as it is called; nothing waits for the
// screen's refresh.
bool fried_renderer_has_vsync(int)
{
    return false;
}

int fried_renderer_get_width(int rendererId)
{
    return s_renderers.get(rendererId) ? layout().m_width : 0;
}

int fried_renderer_get_height(int rendererId)
{
    return s_renderers.get(rendererId) ? layout().m_height : 0;
}

void fried_renderer_set_draw_color(int rendererId, int r, int g, int b, int a)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    renderer->m_r = std::clamp(r, 0, 255);
    renderer->m_g = std::clamp(g, 0, 255);
    renderer->m_b = std::clamp(b, 0, 255);
    renderer->m_a = std::clamp(a, 0, 255);
}

// The bars around a letterboxed viewport are black, and a clear replaces what
// is there rather than blending over it.
void fried_renderer_clear(int rendererId)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }

    uint16_t color = toRgb565(renderer->m_r, renderer->m_g, renderer->m_b);
    FriedDisplayLayout current = layout();
    if (current.m_viewportWidth == DWIDTH && current.m_viewportHeight == DHEIGHT)
    {
        dclear(color);
        return;
    }

    dclear(0);
    drect(
        current.m_viewportX, current.m_viewportY,
        current.m_viewportX + current.m_viewportWidth - 1, current.m_viewportY + current.m_viewportHeight - 1,
        color);
}

void fried_renderer_present(int rendererId)
{
    if (s_renderers.get(rendererId))
    {
        dupdate();
    }
}

void fried_renderer_draw_texture(int rendererId, int textureId, float x, float y, float width, float height)
{
    const FriedGintTexture *texture = fried_texture_get_gint(textureId);
    if (!s_renderers.get(rendererId) || !texture)
    {
        return;
    }
    drawQuad(*texture, {0, 0, texture->m_width, texture->m_height, x, y, width, height, 0.0, false, 0.0f, 0.0f, 0}, 255, 255, 255, 255);
}

// Turned about the quad's centre, as SDL does with no centre given.
void fried_renderer_draw_texture_ex(int rendererId, int textureId, int srcX, int srcY, int srcWidth, int srcHeight, float x, float y, float width, float height, double angle, int flipMode)
{
    const FriedGintTexture *texture = fried_texture_get_gint(textureId);
    if (!s_renderers.get(rendererId) || !texture)
    {
        return;
    }
    drawQuad(*texture, {srcX, srcY, srcWidth, srcHeight, x, y, width, height, angle, false, 0.0f, 0.0f, flipMode}, 255, 255, 255, 255);
}

void fried_renderer_draw_tinted(int rendererId, int textureId, const FriedQuad *quads, int count, int r, int g, int b, int a)
{
    const FriedGintTexture *texture = fried_texture_get_gint(textureId);
    if (!s_renderers.get(rendererId) || !texture)
    {
        return;
    }
    for (int index = 0; index < count; ++index)
    {
        const FriedQuad &quad = quads[index];
        drawQuad(*texture,
            {quad.m_srcX, quad.m_srcY, quad.m_srcWidth, quad.m_srcHeight, quad.m_x, quad.m_y, quad.m_width, quad.m_height, quad.m_angle, true, quad.m_pivotX, quad.m_pivotY, 0},
            std::clamp(r, 0, 255), std::clamp(g, 0, 255), std::clamp(b, 0, 255), std::clamp(a, 0, 255));
    }
}

void fried_renderer_fill_rect(int rendererId, float x, float y, float width, float height)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    fillPixels(toPixels(layout(), x, y, width, height), *renderer);
}

// One logical pixel wide, with the sides between the top and bottom edges so
// no pixel is blended twice.
void fried_renderer_draw_rect(int rendererId, float x, float y, float width, float height)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer || width <= 0.0f || height <= 0.0f)
    {
        return;
    }

    FriedDisplayLayout current = layout();
    PixelRect outer = toPixels(current, x, y, width, height);
    PixelRect inner = toPixels(current, x + 1.0f, y + 1.0f, width - 2.0f, height - 2.0f);

    fillPixels({outer.m_left, outer.m_top, outer.m_right, inner.m_top}, *renderer);
    fillPixels({outer.m_left, inner.m_bottom, outer.m_right, outer.m_bottom}, *renderer);
    fillPixels({outer.m_left, inner.m_top, inner.m_left, inner.m_bottom}, *renderer);
    fillPixels({inner.m_right, inner.m_top, outer.m_right, inner.m_bottom}, *renderer);
}

void fried_renderer_window_to_logical(int, int x, int y, int &logicalX, int &logicalY)
{
    FriedDisplayLayout current = layout();
    logicalX = (int)std::floor((x - current.m_viewportX) / current.m_scaleX);
    logicalY = (int)std::floor((y - current.m_viewportY) / current.m_scaleY);
}

void fried_renderer_touch_to_logical(int, float x, float y, int &logicalX, int &logicalY)
{
    FriedDisplayLayout current = layout();
    logicalX = clampToPixelInside((int)(x * current.m_width), current.m_width);
    logicalY = clampToPixelInside((int)(y * current.m_height), current.m_height);
}

float fried_renderer_get_pixel_scale(int rendererId)
{
    if (!s_renderers.get(rendererId))
    {
        return 1.0f;
    }
    FriedDisplayLayout current = layout();
    return std::min(current.m_scaleX, current.m_scaleY);
}
