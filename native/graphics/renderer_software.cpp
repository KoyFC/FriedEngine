#include "graphics/renderer.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/display.h"
#include "graphics/font.h"
#include "graphics/software_frame.h"
#include "graphics/texture.h"
#include "platform/window.h"

#include <algorithm>
#include <cmath>
#include <cstdint>

// Everything here is drawn into the window's frame by the CPU, through the
// same display layout the other backends hand their GPU. The platform owns
// the frame and sends it to the screen (graphics/software_frame.h).

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

    FriedDisplayLayout layout(const FriedSoftwareFrame &frame)
    {
        return fried_display_layout(frame.m_width, frame.m_height);
    }

    FriedDisplayLayout layout(int windowId)
    {
        return layout(fried_software_frame_get(windowId));
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

    // x / 255 for x up to 255 * 255, exactly, without the division the SH4 and
    // the DS's ARM9 can only do in software.
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
    constexpr uint32_t s_spreadMask = (FRIED_SOFTWARE_HIGH_FIELD << 16) | FRIED_SOFTWARE_LOW_FIELDS;

    __attribute__((always_inline)) inline uint32_t spread(uint16_t color)
    {
        return (color | ((uint32_t)color << 16)) & s_spreadMask;
    }

    __attribute__((always_inline)) inline uint16_t pack(uint32_t spreadColor)
    {
        return (uint16_t)(FRIED_SOFTWARE_OPAQUE_BIT | (spreadColor & FRIED_SOFTWARE_LOW_FIELDS) | (spreadColor >> 16));
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

    // A fill blends one colour at one alpha throughout, so the colour's share
    // of every pixel is worked out once, and what is left per pixel is the
    // share it keeps of the one below: as exact as blendPixel(), with no
    // field able to carry into the next, since neither share is over 31 * 32.
    class SpanBlend
    {
    public:
        SpanBlend(uint16_t color, int blendAlpha) : m_sourceShare(spread(color) * blendAlpha), m_kept(32 - blendAlpha)
        {
        }

        __attribute__((always_inline)) inline uint32_t operator()(uint32_t pixel) const
        {
            return pack(((spread(pixel) * m_kept + m_sourceShare) >> 5) & s_spreadMask);
        }

    private:
        uint32_t m_sourceShare;
        uint32_t m_kept;
    };

    typedef uint32_t __attribute__((may_alias)) PixelPair;

    // Rows of the frame start on four bytes, so two pixels from an even
    // column on are one 32-bit access, the first in the high half.
    void blendRow(uint16_t *row, int left, int right, const SpanBlend &blend)
    {
        if (left & 1)
        {
            row[left] = blend(row[left]);
            ++left;
        }
        PixelPair *pairs = (PixelPair *)(row + left);
        int pairCount = (right - left) >> 1;
        for (int index = 0; index < pairCount; ++index)
        {
            uint32_t pair = pairs[index];
            pairs[index] = ((uint32_t)blend(pair >> 16) << 16) | blend(pair & 0xffff);
        }
        if ((right - left) & 1)
        {
            row[right - 1] = blend(row[right - 1]);
        }
    }

    void fillPixels(const FriedSoftwareFrame &frame, const PixelRect &rect, const Renderer &renderer)
    {
        if (rect.m_left >= rect.m_right || rect.m_top >= rect.m_bottom || renderer.m_a == 0)
        {
            return;
        }

        uint16_t color = fried_software_pack(renderer.m_r, renderer.m_g, renderer.m_b);
        int blendAlpha = toBlendAlpha(renderer.m_a);
        if (blendAlpha == 32)
        {
            fried_software_frame_fill(renderer.m_windowId, rect.m_left, rect.m_top, rect.m_right, rect.m_bottom, color);
            return;
        }

        SpanBlend blend(color, blendAlpha);
        for (int y = rect.m_top; y < rect.m_bottom; ++y)
        {
            blendRow(frame.m_pixels + y * frame.m_width, rect.m_left, rect.m_right, blend);
        }
    }

    int clampToPixelInside(int value, int size)
    {
        return std::clamp(value, 0, std::max(0, size - 1));
    }

    // 64 bits, so stepping an edge's slope cannot overflow.
    struct FixedPoint
    {
        int64_t m_x;
        int64_t m_y;
    };

    constexpr int s_fixedShift = 16;
    constexpr int64_t s_fixedHalf = (int64_t)1 << (s_fixedShift - 1);

    // Keeps the fixed point arithmetic in range.
    constexpr float s_maxCornerDistance = 1.0e6f;

    FixedPoint toFixedPixels(const FriedDisplayLayout &layout, double x, double y)
    {
        float outputX = std::clamp((float)x * layout.m_scaleX, -s_maxCornerDistance, s_maxCornerDistance) + layout.m_viewportX;
        float outputY = std::clamp((float)y * layout.m_scaleY, -s_maxCornerDistance, s_maxCornerDistance) + layout.m_viewportY;
        return {(int64_t)(outputX * (1 << s_fixedShift)), (int64_t)(outputY * (1 << s_fixedShift))};
    }

    // Covering a pixel by its centre means triangles sharing an edge never
    // both draw a pixel on it.
    int firstPixelCentredFrom(int64_t coordinate)
    {
        return (int)((coordinate + s_fixedHalf - 1) >> s_fixedShift);
    }

    class EdgeWalk
    {
    public:
        EdgeWalk(const FixedPoint &top, const FixedPoint &bottom, int firstRow)
        {
            int64_t height = bottom.m_y - top.m_y;
            m_step = height > 0 ? ((bottom.m_x - top.m_x) << s_fixedShift) / height : 0;
            int64_t firstCentre = ((int64_t)firstRow << s_fixedShift) + s_fixedHalf;
            m_x = top.m_x + (((firstCentre - top.m_y) * m_step) >> s_fixedShift);
        }

        int64_t xAtRowCentre() const
        {
            return m_x;
        }

        void nextRow()
        {
            m_x += m_step;
        }

    private:
        int64_t m_x;
        int64_t m_step;
    };

    void fillTriangle(const FriedSoftwareFrame &frame, const FriedDisplayLayout &layout, FixedPoint top, FixedPoint middle, FixedPoint bottom, uint16_t color, int blendAlpha)
    {
        if (middle.m_y < top.m_y)
        {
            std::swap(top, middle);
        }
        if (bottom.m_y < top.m_y)
        {
            std::swap(top, bottom);
        }
        if (bottom.m_y < middle.m_y)
        {
            std::swap(middle, bottom);
        }

        int firstRow = std::max(firstPixelCentredFrom(top.m_y), layout.m_viewportY);
        int endRow = std::min(firstPixelCentredFrom(bottom.m_y), layout.m_viewportY + layout.m_viewportHeight);
        if (firstRow >= endRow)
        {
            return;
        }
        int splitRow = std::clamp(firstPixelCentredFrom(middle.m_y), firstRow, endRow);

        int viewportLeft = layout.m_viewportX;
        int viewportRight = layout.m_viewportX + layout.m_viewportWidth;
        SpanBlend blend(color, blendAlpha);
        EdgeWalk longEdge(top, bottom, firstRow);
        auto fillRows = [&](EdgeWalk &shortEdge, int fromRow, int toRow) {
            for (int row = fromRow; row < toRow; ++row)
            {
                int left = std::max(firstPixelCentredFrom(std::min(longEdge.xAtRowCentre(), shortEdge.xAtRowCentre())), viewportLeft);
                int right = std::min(firstPixelCentredFrom(std::max(longEdge.xAtRowCentre(), shortEdge.xAtRowCentre())), viewportRight);
                if (left < right)
                {
                    uint16_t *pixels = frame.m_pixels + row * frame.m_width;
                    if (blendAlpha == 32)
                    {
                        std::fill(pixels + left, pixels + right, color);
                    }
                    else
                    {
                        blendRow(pixels, left, right, blend);
                    }
                }
                longEdge.nextRow();
                shortEdge.nextRow();
            }
        };

        if (firstRow < splitRow)
        {
            EdgeWalk upperEdge(top, middle, firstRow);
            fillRows(upperEdge, firstRow, splitRow);
        }
        if (splitRow < endRow)
        {
            EdgeWalk lowerEdge(middle, bottom, splitRow);
            fillRows(lowerEdge, splitRow, endRow);
        }
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
    // from one pixel to the next are in 16.16 fixed point, since neither the
    // SH4 nor the DS's ARM9 has a floating point unit.
    void drawQuad(const FriedSoftwareFrame &frame, const FriedSoftwareTexture &texture, const TexturedQuad &quad, int r, int g, int b, int a)
    {
        int srcX = std::max(quad.m_srcX, 0);
        int srcY = std::max(quad.m_srcY, 0);
        int srcWidth = std::min(quad.m_srcX + quad.m_srcWidth, texture.m_width) - srcX;
        int srcHeight = std::min(quad.m_srcY + quad.m_srcHeight, texture.m_height) - srcY;
        if (srcWidth <= 0 || srcHeight <= 0 || a == 0)
        {
            return;
        }

        FriedDisplayLayout current = layout(frame);
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
        uint16_t tint = fried_software_pack(r, g, b);
        uint32_t spreadTint = spread(tint);
        bool flipX = quad.m_flip & s_flipHorizontal;
        bool flipY = quad.m_flip & s_flipVertical;

        for (int y = startY; y < endY; ++y)
        {
            uint16_t *row = frame.m_pixels + y * frame.m_width;
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
                    color = fried_software_pack(
                        divideBy255(fried_software_red(texel) * r),
                        divideBy255(fried_software_green(texel) * g),
                        divideBy255(fried_software_blue(texel) * b));
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

    // A glyph's texels land one to one on output pixels, so each is a
    // coverage looked up and, where it is not empty, the tint written or
    // blended over what is there.
    void drawGlyph(const FriedSoftwareFrame &frame, const FriedSoftwareTexture &texture, const FriedGlyphBlit &glyph, int left, int top, const FriedDisplayLayout &current, uint16_t color, int a)
    {
        int x = left + glyph.m_offsetX;
        int y = top + glyph.m_offsetY;
        int startX = std::max(x, current.m_viewportX);
        int startY = std::max(y, current.m_viewportY);
        int endX = std::min({x + glyph.m_width, current.m_viewportX + current.m_viewportWidth, x + texture.m_width - glyph.m_srcX});
        int endY = std::min({y + glyph.m_height, current.m_viewportY + current.m_viewportHeight, y + texture.m_height - glyph.m_srcY});
        if (startX >= endX || startY >= endY)
        {
            return;
        }

        uint32_t source = spread(color);
        int width = endX - startX;
        for (int row = startY; row < endY; ++row)
        {
            const uint8_t *coverage = texture.m_alpha + (glyph.m_srcY + row - y) * texture.m_width + glyph.m_srcX + startX - x;
            uint16_t *pixel = frame.m_pixels + row * frame.m_width + startX;
            for (int column = 0; column < width; ++column)
            {
                int alpha = coverage[column];
                if (alpha == 0)
                {
                    continue;
                }
                int blendAlpha = toBlendAlpha(a == 255 ? alpha : divideBy255(alpha * a));
                if (blendAlpha == 32)
                {
                    pixel[column] = color;
                }
                else if (blendAlpha > 0)
                {
                    blendPixel(pixel[column], source, blendAlpha);
                }
            }
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
    fried_software_frame_open(windowId);
    return s_renderers.store(new Renderer{windowId, 0, 0, 0, 255});
}

void fried_renderer_destroy(int rendererId)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    int windowId = renderer->m_windowId;
    fried_font_release_renderer(rendererId);
    delete s_renderers.release(rendererId);
    fried_software_frame_close(windowId);
}

bool fried_renderer_has_vsync(int rendererId)
{
    Renderer *renderer = s_renderers.get(rendererId);
    return renderer && fried_software_frame_has_vsync(renderer->m_windowId);
}

int fried_renderer_get_width(int rendererId)
{
    Renderer *renderer = s_renderers.get(rendererId);
    return renderer ? layout(renderer->m_windowId).m_width : 0;
}

int fried_renderer_get_height(int rendererId)
{
    Renderer *renderer = s_renderers.get(rendererId);
    return renderer ? layout(renderer->m_windowId).m_height : 0;
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

    uint16_t color = fried_software_pack(renderer->m_r, renderer->m_g, renderer->m_b);
    FriedSoftwareFrame frame = fried_software_frame_get(renderer->m_windowId);
    FriedDisplayLayout current = layout(frame);
    if (current.m_viewportWidth == frame.m_width && current.m_viewportHeight == frame.m_height)
    {
        fried_software_frame_clear(renderer->m_windowId, color);
        return;
    }

    fried_software_frame_clear(renderer->m_windowId, 0);
    fried_software_frame_fill(
        renderer->m_windowId,
        current.m_viewportX, current.m_viewportY,
        current.m_viewportX + current.m_viewportWidth, current.m_viewportY + current.m_viewportHeight,
        color);
}

void fried_renderer_present(int rendererId)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (renderer)
    {
        fried_software_frame_present(renderer->m_windowId);
    }
}

void fried_renderer_draw_texture(int rendererId, int textureId, float x, float y, float width, float height)
{
    Renderer *renderer = s_renderers.get(rendererId);
    const FriedSoftwareTexture *texture = fried_texture_get_software(textureId);
    if (!renderer || !texture)
    {
        return;
    }
    drawQuad(fried_software_frame_get(renderer->m_windowId), *texture, {0, 0, texture->m_width, texture->m_height, x, y, width, height, 0.0, false, 0.0f, 0.0f, 0}, 255, 255, 255, 255);
}

// Turned about the quad's centre, as SDL does with no centre given.
void fried_renderer_draw_texture_ex(int rendererId, int textureId, int srcX, int srcY, int srcWidth, int srcHeight, float x, float y, float width, float height, double angle, int flipMode)
{
    Renderer *renderer = s_renderers.get(rendererId);
    const FriedSoftwareTexture *texture = fried_texture_get_software(textureId);
    if (!renderer || !texture)
    {
        return;
    }
    drawQuad(fried_software_frame_get(renderer->m_windowId), *texture, {srcX, srcY, srcWidth, srcHeight, x, y, width, height, angle, false, 0.0f, 0.0f, flipMode}, 255, 255, 255, 255);
}

void fried_renderer_draw_tinted(int rendererId, int textureId, const FriedQuad *quads, int count, int r, int g, int b, int a)
{
    Renderer *renderer = s_renderers.get(rendererId);
    const FriedSoftwareTexture *texture = fried_texture_get_software(textureId);
    if (!renderer || !texture)
    {
        return;
    }
    FriedSoftwareFrame frame = fried_software_frame_get(renderer->m_windowId);
    for (int index = 0; index < count; ++index)
    {
        const FriedQuad &quad = quads[index];
        drawQuad(frame, *texture,
            {quad.m_srcX, quad.m_srcY, quad.m_srcWidth, quad.m_srcHeight, quad.m_x, quad.m_y, quad.m_width, quad.m_height, quad.m_angle, true, quad.m_pivotX, quad.m_pivotY, 0},
            std::clamp(r, 0, 255), std::clamp(g, 0, 255), std::clamp(b, 0, 255), std::clamp(a, 0, 255));
    }
}

bool fried_renderer_draw_glyphs(int rendererId, int textureId, float x, float y, const FriedGlyphBlit *glyphs, int count, int r, int g, int b, int a)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return true;
    }
    FriedSoftwareFrame frame = fried_software_frame_get(renderer->m_windowId);
    FriedDisplayLayout current = layout(frame);
    if (current.m_scaleX != 1.0f || current.m_scaleY != 1.0f)
    {
        return false;
    }
    const FriedSoftwareTexture *texture = fried_texture_get_software(textureId);
    if (!texture || !texture->m_alpha || a <= 0)
    {
        return true;
    }

    int left = current.m_viewportX + (int)std::lround(x);
    int top = current.m_viewportY + (int)std::lround(y);
    uint16_t color = fried_software_pack(std::clamp(r, 0, 255), std::clamp(g, 0, 255), std::clamp(b, 0, 255));
    int alpha = std::min(a, 255);
    for (int index = 0; index < count; ++index)
    {
        drawGlyph(frame, *texture, glyphs[index], left, top, current, color, alpha);
    }
    return true;
}

void fried_renderer_fill_rect(int rendererId, float x, float y, float width, float height)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    FriedSoftwareFrame frame = fried_software_frame_get(renderer->m_windowId);
    fillPixels(frame, toPixels(layout(frame), x, y, width, height), *renderer);
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

    FriedSoftwareFrame frame = fried_software_frame_get(renderer->m_windowId);
    FriedDisplayLayout current = layout(frame);
    PixelRect outer = toPixels(current, x, y, width, height);
    PixelRect inner = toPixels(current, x + 1.0f, y + 1.0f, width - 2.0f, height - 2.0f);

    fillPixels(frame, {outer.m_left, outer.m_top, outer.m_right, inner.m_top}, *renderer);
    fillPixels(frame, {outer.m_left, inner.m_bottom, outer.m_right, outer.m_bottom}, *renderer);
    fillPixels(frame, {outer.m_left, inner.m_top, inner.m_left, inner.m_bottom}, *renderer);
    fillPixels(frame, {inner.m_right, inner.m_top, outer.m_right, inner.m_bottom}, *renderer);
}

void fried_renderer_fill_triangles(int rendererId, const double *points, const int *argbColors, int triangleCount)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }

    FriedSoftwareFrame frame = fried_software_frame_get(renderer->m_windowId);
    FriedDisplayLayout current = layout(frame);
    for (int index = 0; index < triangleCount; ++index)
    {
        uint32_t argb = (uint32_t)argbColors[index];
        int blendAlpha = toBlendAlpha((int)(argb >> 24));
        if (blendAlpha == 0)
        {
            continue;
        }
        const double *corners = points + index * 6;
        uint16_t color = fried_software_pack((int)((argb >> 16) & 0xff), (int)((argb >> 8) & 0xff), (int)(argb & 0xff));
        fillTriangle(frame, current, toFixedPixels(current, corners[0], corners[1]), toFixedPixels(current, corners[2], corners[3]),
                     toFixedPixels(current, corners[4], corners[5]), color, blendAlpha);
    }
}

void fried_renderer_window_to_logical(int windowId, int x, int y, int &logicalX, int &logicalY)
{
    FriedDisplayLayout current = layout(windowId);
    logicalX = (int)std::floor((x - current.m_viewportX) / current.m_scaleX);
    logicalY = (int)std::floor((y - current.m_viewportY) / current.m_scaleY);
}

void fried_renderer_touch_to_logical(int windowId, float x, float y, int &logicalX, int &logicalY)
{
    FriedDisplayLayout current = layout(windowId);
    logicalX = clampToPixelInside((int)(x * current.m_width), current.m_width);
    logicalY = clampToPixelInside((int)(y * current.m_height), current.m_height);
}

float fried_renderer_get_pixel_scale(int rendererId)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return 1.0f;
    }
    FriedDisplayLayout current = layout(renderer->m_windowId);
    return std::min(current.m_scaleX, current.m_scaleY);
}
