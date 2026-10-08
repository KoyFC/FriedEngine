#include "graphics/renderer.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/display.h"
#include "graphics/font.h"
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

    void blendPixel(uint16_t &pixel, int r, int g, int b, int a)
    {
        int destinationR = (pixel >> 8) & 0xf8;
        int destinationG = (pixel >> 3) & 0xfc;
        int destinationB = (pixel << 3) & 0xf8;
        pixel = toRgb565(
            (r * a + destinationR * (255 - a)) / 255,
            (g * a + destinationG * (255 - a)) / 255,
            (b * a + destinationB * (255 - a)) / 255);
    }

    void fillPixels(const PixelRect &rect, const Renderer &renderer)
    {
        if (rect.m_left >= rect.m_right || rect.m_top >= rect.m_bottom || renderer.m_a == 0)
        {
            return;
        }

        if (renderer.m_a == 255)
        {
            drect(rect.m_left, rect.m_top, rect.m_right - 1, rect.m_bottom - 1, toRgb565(renderer.m_r, renderer.m_g, renderer.m_b));
            return;
        }

        for (int y = rect.m_top; y < rect.m_bottom; ++y)
        {
            uint16_t *row = gint_vram + y * DWIDTH;
            for (int x = rect.m_left; x < rect.m_right; ++x)
            {
                blendPixel(row[x], renderer.m_r, renderer.m_g, renderer.m_b, renderer.m_a);
            }
        }
    }

    int clampToPixelInside(int value, int size)
    {
        return std::clamp(value, 0, std::max(0, size - 1));
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

// texture_gint.cpp loads no images, so there is never a texture to draw.
void fried_renderer_draw_texture(int, int, float, float, float, float)
{
}

void fried_renderer_draw_texture_ex(int, int, int, int, int, int, float, float, float, float, double, int)
{
}

void fried_renderer_draw_tinted(int, int, const FriedQuad *, int, int, int, int, int)
{
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
