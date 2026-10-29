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
#include <cstring>
#include <vector>

// Everything here is drawn into the window's frame by the CPU, through the
// same display layout the other backends hand their GPU. The platform owns
// the frame and sends it to the screen (graphics/software_frame.h).
//
// A frame is not drawn as the calls come but recorded, as commands in output
// pixels with the bounds each covers, and drawn at present. The frame still
// holds what the last one's commands drew, so only where the two lists differ
// is drawn again, each command clipped to it, and only those rows are sent to
// the screen: a game's screen is mostly what it was a frame ago, and on the
// CPU drawing it all again is what costs.

namespace
{
    struct Renderer
    {
        int m_windowId;
        int m_r;
        int m_g;
        int m_b;
        int m_a;
        std::vector<uint8_t> m_commands;
        std::vector<uint8_t> m_shownCommands;
        FriedDisplayLayout m_shownLayout;
        int m_shownGeneration;
        bool m_hasShown;
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
        auto edge = [](float logical, float scale, int offset) {
            return offset + fried_display_round(scale == 1.0f ? logical : logical * scale);
        };
        PixelRect rect = {
            edge(x, layout.m_scaleX, layout.m_viewportX),
            edge(y, layout.m_scaleY, layout.m_viewportY),
            edge(x + width, layout.m_scaleX, layout.m_viewportX),
            edge(y + height, layout.m_scaleY, layout.m_viewportY),
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

    PixelRect intersect(const PixelRect &a, const PixelRect &b)
    {
        return {std::max(a.m_left, b.m_left), std::max(a.m_top, b.m_top), std::min(a.m_right, b.m_right), std::min(a.m_bottom, b.m_bottom)};
    }

    PixelRect unite(const PixelRect &a, const PixelRect &b)
    {
        return {std::min(a.m_left, b.m_left), std::min(a.m_top, b.m_top), std::max(a.m_right, b.m_right), std::max(a.m_bottom, b.m_bottom)};
    }

    bool isEmpty(const PixelRect &rect)
    {
        return rect.m_left >= rect.m_right || rect.m_top >= rect.m_bottom;
    }

    bool isSame(const PixelRect &a, const PixelRect &b)
    {
        return a.m_left == b.m_left && a.m_top == b.m_top && a.m_right == b.m_right && a.m_bottom == b.m_bottom;
    }

    PixelRect viewportOf(const FriedDisplayLayout &layout)
    {
        return {layout.m_viewportX, layout.m_viewportY, layout.m_viewportX + layout.m_viewportWidth, layout.m_viewportY + layout.m_viewportHeight};
    }

    PixelRect wholeOf(const FriedSoftwareFrame &frame)
    {
        return {0, 0, frame.m_width, frame.m_height};
    }

    void fillPixels(int windowId, const FriedSoftwareFrame &frame, const PixelRect &rect, uint16_t color, int blendAlpha)
    {
        if (isEmpty(rect) || blendAlpha == 0)
        {
            return;
        }
        if (blendAlpha == 32)
        {
            fried_software_frame_fill(windowId, rect.m_left, rect.m_top, rect.m_right, rect.m_bottom, color);
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

    // Corners sorted from the top down.
    struct Triangle
    {
        FixedPoint m_top;
        FixedPoint m_middle;
        FixedPoint m_bottom;
        int32_t m_color;
        int32_t m_blendAlpha;
    };

    Triangle sortedTriangle(FixedPoint top, FixedPoint middle, FixedPoint bottom, uint16_t color, int blendAlpha)
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
        Triangle triangle;
        std::memset(&triangle, 0, sizeof(triangle));
        triangle.m_top = top;
        triangle.m_middle = middle;
        triangle.m_bottom = bottom;
        triangle.m_color = color;
        triangle.m_blendAlpha = blendAlpha;
        return triangle;
    }

    PixelRect boundsOf(const Triangle &triangle)
    {
        int64_t left = std::min({triangle.m_top.m_x, triangle.m_middle.m_x, triangle.m_bottom.m_x});
        int64_t right = std::max({triangle.m_top.m_x, triangle.m_middle.m_x, triangle.m_bottom.m_x});
        return {firstPixelCentredFrom(left), firstPixelCentredFrom(triangle.m_top.m_y), firstPixelCentredFrom(right), firstPixelCentredFrom(triangle.m_bottom.m_y)};
    }

    void fillTriangle(const FriedSoftwareFrame &frame, const PixelRect &clip, const Triangle &triangle)
    {
        int firstRow = std::max(firstPixelCentredFrom(triangle.m_top.m_y), clip.m_top);
        int endRow = std::min(firstPixelCentredFrom(triangle.m_bottom.m_y), clip.m_bottom);
        if (firstRow >= endRow)
        {
            return;
        }
        int splitRow = std::clamp(firstPixelCentredFrom(triangle.m_middle.m_y), firstRow, endRow);

        uint16_t color = (uint16_t)triangle.m_color;
        int blendAlpha = triangle.m_blendAlpha;
        SpanBlend blend(color, blendAlpha);
        EdgeWalk longEdge(triangle.m_top, triangle.m_bottom, firstRow);
        auto fillRows = [&](EdgeWalk &shortEdge, int fromRow, int toRow) {
            for (int row = fromRow; row < toRow; ++row)
            {
                int left = std::max(firstPixelCentredFrom(std::min(longEdge.xAtRowCentre(), shortEdge.xAtRowCentre())), clip.m_left);
                int right = std::min(firstPixelCentredFrom(std::max(longEdge.xAtRowCentre(), shortEdge.xAtRowCentre())), clip.m_right);
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
            EdgeWalk upperEdge(triangle.m_top, triangle.m_middle, firstRow);
            fillRows(upperEdge, firstRow, splitRow);
        }
        if (splitRow < endRow)
        {
            EdgeWalk lowerEdge(triangle.m_middle, triangle.m_bottom, splitRow);
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

    // A quad worked out in output pixels: the bounds it covers, and the texel
    // under the centre of the first pixel with the steps from one pixel to
    // the next, in 16.16 fixed point, since neither the SH4 nor the DS's ARM9
    // has a floating point unit. Drawn again, it costs no float operation.
    struct QuadSetup
    {
        int32_t m_textureId;
        int32_t m_srcX;
        int32_t m_srcY;
        int32_t m_srcWidth;
        int32_t m_srcHeight;
        int32_t m_rowU;
        int32_t m_rowV;
        int32_t m_stepUAcross;
        int32_t m_stepVAcross;
        int32_t m_stepUDown;
        int32_t m_stepVDown;
        int32_t m_flip;
        int32_t m_r;
        int32_t m_g;
        int32_t m_b;
        int32_t m_a;
    };

    // Each screen pixel in the quad's bounds is mapped back through the
    // rotation and the scale to the texel it shows, nearest first.
    bool setUpQuad(const FriedDisplayLayout &current, int textureId, const FriedSoftwareTexture &texture, const TexturedQuad &quad, int r, int g, int b, int a, QuadSetup &setup, PixelRect &bounds)
    {
        int srcX = std::max(quad.m_srcX, 0);
        int srcY = std::max(quad.m_srcY, 0);
        int srcWidth = std::min(quad.m_srcX + quad.m_srcWidth, texture.m_width) - srcX;
        int srcHeight = std::min(quad.m_srcY + quad.m_srcHeight, texture.m_height) - srcY;
        if (srcWidth <= 0 || srcHeight <= 0 || a == 0)
        {
            return false;
        }

        float left = current.m_viewportX + std::round(quad.m_x * current.m_scaleX);
        float top = current.m_viewportY + std::round(quad.m_y * current.m_scaleY);
        float right = current.m_viewportX + std::round((quad.m_x + quad.m_width) * current.m_scaleX);
        float bottom = current.m_viewportY + std::round((quad.m_y + quad.m_height) * current.m_scaleY);
        float width = right - left;
        float height = bottom - top;
        if (width <= 0.0f || height <= 0.0f)
        {
            return false;
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
        bounds = intersect({(int)std::floor(minX), (int)std::floor(minY), (int)std::ceil(maxX), (int)std::ceil(maxY)}, viewportOf(current));
        if (isEmpty(bounds))
        {
            return false;
        }

        // The texel under a pixel's centre, turned back by the angle and
        // scaled from the quad to the source region.
        float scaleU = srcWidth / width;
        float scaleV = srcHeight / height;
        float centreX = bounds.m_left + 0.5f - pivotX;
        float centreY = bounds.m_top + 0.5f - pivotY;
        float u = (cosine * centreX + sine * centreY + pivotX - left) * scaleU;
        float v = (-sine * centreX + cosine * centreY + pivotY - top) * scaleV;

        constexpr float s_one = 65536.0f;
        std::memset(&setup, 0, sizeof(setup));
        setup.m_textureId = textureId;
        setup.m_srcX = srcX;
        setup.m_srcY = srcY;
        setup.m_srcWidth = srcWidth;
        setup.m_srcHeight = srcHeight;
        setup.m_rowU = (int32_t)(u * s_one);
        setup.m_rowV = (int32_t)(v * s_one);
        setup.m_stepUAcross = (int32_t)(cosine * scaleU * s_one);
        setup.m_stepVAcross = (int32_t)(-sine * scaleV * s_one);
        setup.m_stepUDown = (int32_t)(sine * scaleU * s_one);
        setup.m_stepVDown = (int32_t)(cosine * scaleV * s_one);
        setup.m_flip = quad.m_flip;
        setup.m_r = r;
        setup.m_g = g;
        setup.m_b = b;
        setup.m_a = a;
        return true;
    }

    void drawQuad(const FriedSoftwareFrame &frame, const FriedSoftwareTexture &texture, const QuadSetup &setup, const PixelRect &bounds, const PixelRect &clip)
    {
        PixelRect area = intersect(bounds, clip);
        if (isEmpty(area))
        {
            return;
        }

        int r = setup.m_r;
        int g = setup.m_g;
        int b = setup.m_b;
        int a = setup.m_a;
        int srcX = setup.m_srcX;
        int srcY = setup.m_srcY;
        int srcWidth = setup.m_srcWidth;
        int srcHeight = setup.m_srcHeight;
        uint32_t limitU = (uint32_t)srcWidth << 16;
        uint32_t limitV = (uint32_t)srcHeight << 16;
        int skippedRows = area.m_top - bounds.m_top;
        int skippedColumns = area.m_left - bounds.m_left;
        int32_t rowU = setup.m_rowU + skippedRows * setup.m_stepUDown + skippedColumns * setup.m_stepUAcross;
        int32_t rowV = setup.m_rowV + skippedRows * setup.m_stepVDown + skippedColumns * setup.m_stepVAcross;

        // A blank texture is white, so tinted it is one colour throughout.
        bool tinted = r != 255 || g != 255 || b != 255;
        uint16_t tint = fried_software_pack(r, g, b);
        uint32_t spreadTint = spread(tint);
        bool flipX = setup.m_flip & s_flipHorizontal;
        bool flipY = setup.m_flip & s_flipVertical;

        for (int y = area.m_top; y < area.m_bottom; ++y)
        {
            uint16_t *row = frame.m_pixels + y * frame.m_width;
            int32_t texelU = rowU;
            int32_t texelV = rowV;
            for (int x = area.m_left; x < area.m_right; ++x, texelU += setup.m_stepUAcross, texelV += setup.m_stepVAcross)
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
            rowU += setup.m_stepUDown;
            rowV += setup.m_stepVDown;
        }
    }

    // Where a glyph lands, cut to what the texture holds.
    PixelRect boundsOf(const FriedSoftwareTexture &texture, const FriedGlyphBlit &glyph, int left, int top)
    {
        int x = left + glyph.m_offsetX;
        int y = top + glyph.m_offsetY;
        return {x, y, std::min(x + glyph.m_width, x + texture.m_width - glyph.m_srcX), std::min(y + glyph.m_height, y + texture.m_height - glyph.m_srcY)};
    }

    // A glyph's texels land one to one on output pixels, so each is a
    // coverage looked up and, where it is not empty, the tint written or
    // blended over what is there.
    void drawGlyph(const FriedSoftwareFrame &frame, const FriedSoftwareTexture &texture, const FriedGlyphBlit &glyph, int left, int top, const PixelRect &clip, uint16_t color, int a)
    {
        int x = left + glyph.m_offsetX;
        int y = top + glyph.m_offsetY;
        PixelRect area = intersect(boundsOf(texture, glyph, left, top), clip);
        if (isEmpty(area))
        {
            return;
        }

        uint32_t source = spread(color);
        int width = area.m_right - area.m_left;
        for (int row = area.m_top; row < area.m_bottom; ++row)
        {
            const uint8_t *coverage = texture.m_alpha + (glyph.m_srcY + row - y) * texture.m_width + glyph.m_srcX + area.m_left - x;
            uint16_t *pixel = frame.m_pixels + row * frame.m_width + area.m_left;
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

    // A frame's commands, one after another in a byte list: a header, then
    // what the command draws with. Every byte of a command is set, padding
    // included, so two that draw the same compare equal byte for byte.
    enum CommandType : int32_t
    {
        ClearCommand,
        FillCommand,
        QuadCommand,
        GlyphsCommand,
        TriangleCommand,
    };

    struct CommandHeader
    {
        int32_t m_type;
        int32_t m_size;
        PixelRect m_bounds;
    };

    struct Fill
    {
        int32_t m_color;
        int32_t m_blendAlpha;
    };

    // A clear is the viewport's colour inside it and black around it.
    struct Clear
    {
        int32_t m_color;
    };

    struct Glyphs
    {
        int32_t m_textureId;
        int32_t m_left;
        int32_t m_top;
        int32_t m_color;
        int32_t m_alpha;
        int32_t m_count;
    };

    void record(Renderer &renderer, CommandType type, const PixelRect &bounds, const void *command, size_t size, const void *extra = nullptr, size_t extraSize = 0)
    {
        CommandHeader header = {type, (int32_t)(size + extraSize), bounds};
        std::vector<uint8_t> &commands = renderer.m_commands;
        size_t at = commands.size();
        commands.resize(at + sizeof(header) + size + extraSize);
        std::memcpy(commands.data() + at, &header, sizeof(header));
        std::memcpy(commands.data() + at + sizeof(header), command, size);
        if (extraSize > 0)
        {
            std::memcpy(commands.data() + at + sizeof(header) + size, extra, extraSize);
        }
    }

    void recordFill(Renderer &renderer, const PixelRect &rect)
    {
        int blendAlpha = toBlendAlpha(renderer.m_a);
        if (isEmpty(rect) || blendAlpha == 0)
        {
            return;
        }
        Fill fill = {fried_software_pack(renderer.m_r, renderer.m_g, renderer.m_b), blendAlpha};
        record(renderer, FillCommand, rect, &fill, sizeof(fill));
    }

    void recordQuad(Renderer &renderer, int textureId, const TexturedQuad &quad, int r, int g, int b, int a)
    {
        const FriedSoftwareTexture *texture = fried_texture_get_software(textureId);
        if (!texture)
        {
            return;
        }
        QuadSetup setup;
        PixelRect bounds;
        if (setUpQuad(layout(renderer.m_windowId), textureId, *texture, quad, r, g, b, a, setup, bounds))
        {
            record(renderer, QuadCommand, bounds, &setup, sizeof(setup));
        }
    }

    template <typename T>
    T read(const uint8_t *at)
    {
        T value;
        std::memcpy(&value, at, sizeof(value));
        return value;
    }

    template <typename Visit>
    void forEachCommand(const std::vector<uint8_t> &commands, Visit visit)
    {
        size_t at = 0;
        while (at < commands.size())
        {
            CommandHeader header = read<CommandHeader>(commands.data() + at);
            visit(header, commands.data() + at + sizeof(header));
            at += sizeof(header) + header.m_size;
        }
    }

    void replay(const Renderer &renderer, const FriedSoftwareFrame &frame, const FriedDisplayLayout &current, const CommandHeader &header, const uint8_t *command, const PixelRect &clip)
    {
        PixelRect area = intersect(header.m_bounds, clip);
        if (isEmpty(area))
        {
            return;
        }
        switch (header.m_type)
        {
        case ClearCommand:
        {
            uint16_t color = (uint16_t)read<Clear>(command).m_color;
            PixelRect whole = wholeOf(frame);
            PixelRect viewport = viewportOf(current);
            if (isSame(area, whole) && isSame(viewport, whole))
            {
                fried_software_frame_clear(renderer.m_windowId, color);
                break;
            }
            PixelRect inside = intersect(area, viewport);
            if (!isSame(inside, area))
            {
                fillPixels(renderer.m_windowId, frame, area, 0, 32);
            }
            fillPixels(renderer.m_windowId, frame, inside, color, 32);
            break;
        }
        case FillCommand:
        {
            Fill fill = read<Fill>(command);
            fillPixels(renderer.m_windowId, frame, area, (uint16_t)fill.m_color, fill.m_blendAlpha);
            break;
        }
        case QuadCommand:
        {
            QuadSetup setup = read<QuadSetup>(command);
            const FriedSoftwareTexture *texture = fried_texture_get_software(setup.m_textureId);
            if (texture)
            {
                drawQuad(frame, *texture, setup, header.m_bounds, area);
            }
            break;
        }
        case GlyphsCommand:
        {
            Glyphs glyphs = read<Glyphs>(command);
            const FriedSoftwareTexture *texture = fried_texture_get_software(glyphs.m_textureId);
            if (!texture || !texture->m_alpha)
            {
                break;
            }
            const uint8_t *blits = command + sizeof(Glyphs);
            for (int index = 0; index < glyphs.m_count; ++index)
            {
                FriedGlyphBlit glyph = read<FriedGlyphBlit>(blits + index * sizeof(FriedGlyphBlit));
                drawGlyph(frame, *texture, glyph, glyphs.m_left, glyphs.m_top, area, (uint16_t)glyphs.m_color, glyphs.m_alpha);
            }
            break;
        }
        case TriangleCommand:
            fillTriangle(frame, area, read<Triangle>(command));
            break;
        }
    }

    // At most a few regions, each grown over any other it touches, so the
    // commands under a region are not drawn again for a neighbour of it.
    constexpr size_t s_maxRegions = 8;

    class Regions
    {
    public:
        explicit Regions(const PixelRect &whole) : m_whole(whole)
        {
        }

        void add(PixelRect rect)
        {
            rect = intersect(rect, m_whole);
            if (isEmpty(rect))
            {
                return;
            }
            for (size_t index = 0; index < m_rects.size();)
            {
                const PixelRect &other = m_rects[index];
                bool touches = rect.m_left <= other.m_right && other.m_left <= rect.m_right && rect.m_top <= other.m_bottom && other.m_top <= rect.m_bottom;
                if (touches)
                {
                    rect = unite(rect, other);
                    m_rects.erase(m_rects.begin() + index);
                    index = 0;
                    continue;
                }
                ++index;
            }
            m_rects.push_back(rect);
            if (m_rects.size() > s_maxRegions)
            {
                PixelRect all = m_rects.front();
                for (const PixelRect &other : m_rects)
                {
                    all = unite(all, other);
                }
                m_rects.assign(1, all);
            }
        }

        const std::vector<PixelRect> &rects() const
        {
            return m_rects;
        }

    private:
        PixelRect m_whole;
        std::vector<PixelRect> m_rects;
    };

    // Commands are matched by their place in the list, so one that comes or
    // goes marks every one after it, which is never wrong, only more to draw.
    void collectChanges(const Renderer &renderer, const FriedDisplayLayout &current, Regions &regions, const PixelRect &whole)
    {
        bool sameLayout = std::memcmp(&current, &renderer.m_shownLayout, sizeof(current)) == 0;
        if (!renderer.m_hasShown || !sameLayout || renderer.m_shownGeneration != fried_texture_get_software_generation())
        {
            regions.add(whole);
            return;
        }

        const std::vector<uint8_t> &before = renderer.m_shownCommands;
        const std::vector<uint8_t> &after = renderer.m_commands;
        size_t atBefore = 0;
        size_t atAfter = 0;
        while (atBefore < before.size() || atAfter < after.size())
        {
            bool hasBefore = atBefore < before.size();
            bool hasAfter = atAfter < after.size();
            CommandHeader headerBefore = hasBefore ? read<CommandHeader>(before.data() + atBefore) : CommandHeader{};
            CommandHeader headerAfter = hasAfter ? read<CommandHeader>(after.data() + atAfter) : CommandHeader{};
            size_t sizeBefore = hasBefore ? sizeof(CommandHeader) + headerBefore.m_size : 0;
            size_t sizeAfter = hasAfter ? sizeof(CommandHeader) + headerAfter.m_size : 0;
            bool same = hasBefore && hasAfter && sizeBefore == sizeAfter && std::memcmp(before.data() + atBefore, after.data() + atAfter, sizeBefore) == 0;
            if (!same)
            {
                if (hasBefore)
                {
                    regions.add(headerBefore.m_bounds);
                }
                if (hasAfter)
                {
                    regions.add(headerAfter.m_bounds);
                }
            }
            atBefore += sizeBefore;
            atAfter += sizeAfter;
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
    Renderer *renderer = new Renderer();
    renderer->m_windowId = windowId;
    renderer->m_a = 255;
    return s_renderers.store(renderer);
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
// is there rather than blending over it. It covers what was drawn before it
// this frame, so that is dropped.
void fried_renderer_clear(int rendererId)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    renderer->m_commands.clear();
    Clear clear = {fried_software_pack(renderer->m_r, renderer->m_g, renderer->m_b)};
    record(*renderer, ClearCommand, wholeOf(fried_software_frame_get(renderer->m_windowId)), &clear, sizeof(clear));
}

void fried_renderer_present(int rendererId)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }

    FriedSoftwareFrame frame = fried_software_frame_get(renderer->m_windowId);
    FriedDisplayLayout current = layout(frame);
    PixelRect whole = wholeOf(frame);
    if (fried_software_frame_take_lost(renderer->m_windowId))
    {
        renderer->m_hasShown = false;
    }

    Regions regions(whole);
    collectChanges(*renderer, current, regions, whole);
    int top = frame.m_height;
    int bottom = 0;
    for (const PixelRect &region : regions.rects())
    {
        forEachCommand(renderer->m_commands, [&](const CommandHeader &header, const uint8_t *command) {
            replay(*renderer, frame, current, header, command, region);
        });
        top = std::min(top, region.m_top);
        bottom = std::max(bottom, region.m_bottom);
    }
    fried_software_frame_present(renderer->m_windowId, top, bottom);
    renderer->m_shownCommands.swap(renderer->m_commands);
    renderer->m_commands.clear();
    renderer->m_shownLayout = current;
    renderer->m_shownGeneration = fried_texture_get_software_generation();
    renderer->m_hasShown = true;
}

void fried_renderer_draw_texture(int rendererId, int textureId, float x, float y, float width, float height)
{
    Renderer *renderer = s_renderers.get(rendererId);
    const FriedSoftwareTexture *texture = fried_texture_get_software(textureId);
    if (!renderer || !texture)
    {
        return;
    }
    recordQuad(*renderer, textureId, {0, 0, texture->m_width, texture->m_height, x, y, width, height, 0.0, false, 0.0f, 0.0f, 0}, 255, 255, 255, 255);
}

// Turned about the quad's centre, as SDL does with no centre given.
void fried_renderer_draw_texture_ex(int rendererId, int textureId, int srcX, int srcY, int srcWidth, int srcHeight, float x, float y, float width, float height, double angle, int flipMode)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    recordQuad(*renderer, textureId, {srcX, srcY, srcWidth, srcHeight, x, y, width, height, angle, false, 0.0f, 0.0f, flipMode}, 255, 255, 255, 255);
}

void fried_renderer_draw_tinted(int rendererId, int textureId, const FriedQuad *quads, int count, int r, int g, int b, int a)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    for (int index = 0; index < count; ++index)
    {
        const FriedQuad &quad = quads[index];
        recordQuad(*renderer, textureId,
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
    FriedDisplayLayout current = layout(renderer->m_windowId);
    if (current.m_scaleX != 1.0f || current.m_scaleY != 1.0f)
    {
        return false;
    }
    const FriedSoftwareTexture *texture = fried_texture_get_software(textureId);
    if (!texture || !texture->m_alpha || a <= 0 || count <= 0)
    {
        return true;
    }

    Glyphs command;
    std::memset(&command, 0, sizeof(command));
    command.m_textureId = textureId;
    command.m_left = current.m_viewportX + fried_display_round(x);
    command.m_top = current.m_viewportY + fried_display_round(y);
    command.m_color = fried_software_pack(std::clamp(r, 0, 255), std::clamp(g, 0, 255), std::clamp(b, 0, 255));
    command.m_alpha = std::min(a, 255);
    command.m_count = count;
    PixelRect bounds = boundsOf(*texture, glyphs[0], command.m_left, command.m_top);
    for (int index = 1; index < count; ++index)
    {
        bounds = unite(bounds, boundsOf(*texture, glyphs[index], command.m_left, command.m_top));
    }
    bounds = intersect(bounds, viewportOf(current));
    if (!isEmpty(bounds))
    {
        record(*renderer, GlyphsCommand, bounds, &command, sizeof(command), glyphs, count * sizeof(FriedGlyphBlit));
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
    recordFill(*renderer, toPixels(layout(renderer->m_windowId), x, y, width, height));
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

    FriedDisplayLayout current = layout(renderer->m_windowId);
    PixelRect outer = toPixels(current, x, y, width, height);
    PixelRect inner = toPixels(current, x + 1.0f, y + 1.0f, width - 2.0f, height - 2.0f);

    recordFill(*renderer, {outer.m_left, outer.m_top, outer.m_right, inner.m_top});
    recordFill(*renderer, {outer.m_left, inner.m_bottom, outer.m_right, outer.m_bottom});
    recordFill(*renderer, {outer.m_left, inner.m_top, inner.m_left, inner.m_bottom});
    recordFill(*renderer, {inner.m_right, inner.m_top, outer.m_right, inner.m_bottom});
}

void fried_renderer_fill_triangles(int rendererId, const double *points, const int *argbColors, int triangleCount)
{
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }

    FriedDisplayLayout current = layout(renderer->m_windowId);
    PixelRect viewport = viewportOf(current);
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
        Triangle triangle = sortedTriangle(toFixedPixels(current, corners[0], corners[1]), toFixedPixels(current, corners[2], corners[3]),
                                           toFixedPixels(current, corners[4], corners[5]), color, blendAlpha);
        PixelRect bounds = intersect(boundsOf(triangle), viewport);
        if (!isEmpty(bounds))
        {
            record(*renderer, TriangleCommand, bounds, &triangle, sizeof(triangle));
        }
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
