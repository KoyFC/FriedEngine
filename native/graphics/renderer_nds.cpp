#include "graphics/renderer.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/display.h"
#include "graphics/font.h"
#include "graphics/software_backend_nds.h"
#include "graphics/texture.h"
#include "platform/window.h"

#include <nds.h>

#include <algorithm>
#include <cmath>

// The top screen is drawn by the DS's 3D engine through videoGL, as quads and
// triangles in screen pixels. The bottom one, when it is a window, is drawn by
// the software renderer the calculator uses, whose calls this hands on with
// its own ids: a public id from FRIED_SOFTWARE_ID_BASE on is one of its
// renderers or textures. The projection is orthographic over the screen,
// with one unit of a vertex a pixel.
//
// Draw order: every polygon is a step nearer than the one before, so a later
// one covers an earlier one whatever kind each is. The engine draws opaque
// polygons before translucent ones, and the translucent ones in the order they
// came, so depth is what keeps the order across the two. Translucent pixels do
// not blend over others of the same polygon ID, so each translucent draw takes
// the next ID.

namespace
{
    struct Renderer
    {
        int m_windowId;
        FriedDisplayLayout m_layout;
        int m_r;
        int m_g;
        int m_b;
        int m_a;
    };

    HandlePool<Renderer> s_renderers;

    constexpr int s_screenWidth = 256;
    constexpr int s_screenHeight = 192;

    // Well inside the projection's depth range of -4096 to 4096, which is
    // more steps than the 2048 polygons the engine draws in a frame.
    constexpr int s_firstDepth = -4000;
    constexpr int s_lastDepth = 4000;
    int s_depth = s_firstDepth;

    // 0 is the clear plane's, which no polygon blends against anyway.
    constexpr int s_firstTranslucentId = 1;
    constexpr int s_lastTranslucentId = 62;
    int s_translucentId = s_firstTranslucentId;

    // Keeps a vertex within what 16 bits hold.
    constexpr float s_maxCoordinate = 4096.0f;

    constexpr int s_flipHorizontal = 1;
    constexpr int s_flipVertical = 2;
    constexpr float s_degreesToRadians = 3.14159265358979f / 180.0f;

    bool s_started = false;

    constexpr int s_bottomWindowId = 1;

    bool isSoftware(int id)
    {
        return id >= FRIED_SOFTWARE_ID_BASE;
    }

    int softwareId(int id)
    {
        return id - FRIED_SOFTWARE_ID_BASE;
    }

    // A texture of one side drawn by the other is not found there, so it is
    // left out as a texture that is not loaded would be.
    int softwareTextureId(int id)
    {
        return isSoftware(id) ? softwareId(id) : -1;
    }

    void startEngine()
    {
        videoSetMode(MODE_0_3D);
        vramSetBankA(VRAM_A_TEXTURE);
        vramSetBankB(VRAM_B_TEXTURE);
        vramSetBankE(VRAM_E_TEX_PALETTE);

        glInit();
        glEnable(GL_TEXTURE_2D | GL_BLEND);
        glClearColor(0, 0, 0, 31);
        glClearPolyID(63);
        glClearDepth(GL_MAX_DEPTH);
        glViewport(0, 0, s_screenWidth - 1, s_screenHeight - 1);

        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrthof32(0, s_screenWidth, s_screenHeight, 0, -4096, 4096);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        s_started = true;
    }

    int toVertexUnits(float coordinate)
    {
        return fried_display_round(std::clamp(coordinate, -s_maxCoordinate, s_maxCoordinate));
    }

    // Output pixels, right and bottom excluded.
    struct Edges
    {
        int m_left;
        int m_top;
        int m_right;
        int m_bottom;
    };

    // The output pixel a logical edge lands on, as fried_display_snap() puts it.
    int outputEdge(float logical, float scale, int offset)
    {
        return offset + toVertexUnits(scale == 1.0f ? logical : logical * scale);
    }

    Edges outputEdges(const FriedDisplayLayout &layout, float x, float y, float width, float height)
    {
        return {
            outputEdge(x, layout.m_scaleX, layout.m_viewportX),
            outputEdge(y, layout.m_scaleY, layout.m_viewportY),
            outputEdge(x + width, layout.m_scaleX, layout.m_viewportX),
            outputEdge(y + height, layout.m_scaleY, layout.m_viewportY),
        };
    }

    bool isEmpty(const Edges &edges)
    {
        return edges.m_right <= edges.m_left || edges.m_bottom <= edges.m_top;
    }

    // From 0..255 to the five bits a polygon's alpha has.
    int toPolygonAlpha(int alpha)
    {
        return (std::clamp(alpha, 0, 255) * 31 + 127) / 255;
    }

    uint16_t toVertexColor(int r, int g, int b)
    {
        return RGB15(std::clamp(r, 0, 255) >> 3, std::clamp(g, 0, 255) >> 3, std::clamp(b, 0, 255) >> 3);
    }

    // Starts the polygons of one draw, at one alpha and with one texture or
    // none. An alpha of zero is how the engine asks for a wireframe, so
    // nothing that faint is drawn.
    bool beginPolygons(GL_GLBEGIN_ENUM kind, int alpha, const FriedNdsTexture *texture)
    {
        int polygonAlpha = toPolygonAlpha(alpha);
        if (polygonAlpha == 0)
        {
            return false;
        }
        int id = 0;
        if (polygonAlpha < 31 || (texture && texture->m_translucent))
        {
            id = s_translucentId;
            s_translucentId = s_translucentId == s_lastTranslucentId ? s_firstTranslucentId : s_translucentId + 1;
        }
        glPolyFmt(POLY_ALPHA(polygonAlpha) | POLY_CULL_NONE | POLY_ID(id));
        glBindTexture(0, texture ? texture->m_name : 0);
        glBegin(kind);
        return true;
    }

    int nextDepth()
    {
        if (s_depth < s_lastDepth)
        {
            ++s_depth;
        }
        return s_depth;
    }

    struct Corner
    {
        float m_x;
        float m_y;
    };

    // Texel coordinates are 12.4 fixed point.
    __attribute__((always_inline)) inline void vertex(int x, int y, int u, int v, int depth)
    {
        glTexCoord2t16((t16)u, (t16)v);
        glVertex3v16((v16)x, (v16)y, (v16)depth);
    }

    void vertex(const Corner &corner, int u, int v, int depth)
    {
        vertex(toVertexUnits(corner.m_x), toVertexUnits(corner.m_y), u, v, depth);
    }

    // One write instead of two, for a vertex at the depth of the one before.
    __attribute__((always_inline)) inline void vertexAtSameDepth(int x, int y, int u, int v)
    {
        glTexCoord2t16((t16)u, (t16)v);
        GFX_VERTEX_XY = ((uint32_t)y << 16) | ((uint32_t)x & 0xffff);
    }

    // Corners go round from the top left, and so do the texels they show.
    void quad(const Corner corners[4], int u0, int v0, int u1, int v1)
    {
        int depth = nextDepth();
        vertex(corners[0], u0, v0, depth);
        vertex(corners[1], u1, v0, depth);
        vertex(corners[2], u1, v1, depth);
        vertex(corners[3], u0, v1, depth);
    }

    // A rectangle in output pixels, turned about a point by an angle in degrees.
    void cornersOf(float left, float top, float right, float bottom, float pivotX, float pivotY, float angle, Corner corners[4])
    {
        corners[0] = {left, top};
        corners[1] = {right, top};
        corners[2] = {right, bottom};
        corners[3] = {left, bottom};
        if (angle == 0.0f)
        {
            return;
        }
        float radians = angle * s_degreesToRadians;
        float cosine = std::cos(radians);
        float sine = std::sin(radians);
        for (int index = 0; index < 4; ++index)
        {
            float offsetX = corners[index].m_x - pivotX;
            float offsetY = corners[index].m_y - pivotY;
            corners[index] = {pivotX + cosine * offsetX - sine * offsetY, pivotY + sine * offsetX + cosine * offsetY};
        }
    }

    void quad(const Edges &edges, int u0, int v0, int u1, int v1)
    {
        vertex(edges.m_left, edges.m_top, u0, v0, nextDepth());
        vertexAtSameDepth(edges.m_right, edges.m_top, u1, v0);
        vertexAtSameDepth(edges.m_right, edges.m_bottom, u1, v1);
        vertexAtSameDepth(edges.m_left, edges.m_bottom, u0, v1);
    }

    void fillEdges(const Edges &edges, int r, int g, int b, int a)
    {
        if (isEmpty(edges) || !beginPolygons(GL_QUADS, a, nullptr))
        {
            return;
        }
        glColor(toVertexColor(r, g, b));
        quad(edges, 0, 0, 0, 0);
        glEnd();
    }

    // The source region in the stored texture's texels, as 12.4 fixed point.
    struct TexelRegion
    {
        int m_u0;
        int m_v0;
        int m_u1;
        int m_v1;
    };

    TexelRegion regionOf(const FriedNdsTexture &texture, int srcX, int srcY, int srcWidth, int srcHeight, int flipMode)
    {
        int scale = texture.m_downscale;
        TexelRegion region = {(srcX << 4) / scale, (srcY << 4) / scale, ((srcX + srcWidth) << 4) / scale, ((srcY + srcHeight) << 4) / scale};
        if (flipMode & s_flipHorizontal)
        {
            std::swap(region.m_u0, region.m_u1);
        }
        if (flipMode & s_flipVertical)
        {
            std::swap(region.m_v0, region.m_v1);
        }
        return region;
    }

    void drawTexturedQuad(const Renderer &renderer, const FriedNdsTexture &texture, const TexelRegion &region, float x, float y, float width, float height, float angle, bool hasPivot, float pivotX, float pivotY)
    {
        const FriedDisplayLayout &layout = renderer.m_layout;
        Edges edges = outputEdges(layout, x, y, width, height);
        if (angle == 0.0f)
        {
            quad(edges, region.m_u0, region.m_v0, region.m_u1, region.m_v1);
            return;
        }
        float left = (float)edges.m_left;
        float top = (float)edges.m_top;
        float right = (float)edges.m_right;
        float bottom = (float)edges.m_bottom;
        float outputPivotX = hasPivot ? layout.m_viewportX + pivotX * layout.m_scaleX : (left + right) / 2.0f;
        float outputPivotY = hasPivot ? layout.m_viewportY + pivotY * layout.m_scaleY : (top + bottom) / 2.0f;
        Corner corners[4];
        cornersOf(left, top, right, bottom, outputPivotX, outputPivotY, angle, corners);
        quad(corners, region.m_u0, region.m_v0, region.m_u1, region.m_v1);
    }

    // Painted over the frame rather than clipped to, so whatever was drawn past
    // the viewport is hidden too.
    void drawLetterboxBars(const FriedDisplayLayout &layout)
    {
        int viewportRight = layout.m_viewportX + layout.m_viewportWidth;
        int viewportBottom = layout.m_viewportY + layout.m_viewportHeight;
        int viewportLeft = layout.m_viewportX;
        int viewportTop = layout.m_viewportY;
        fillEdges({0, 0, s_screenWidth, viewportTop}, 0, 0, 0, 255);
        fillEdges({0, viewportBottom, s_screenWidth, s_screenHeight}, 0, 0, 0, 255);
        fillEdges({0, viewportTop, viewportLeft, viewportBottom}, 0, 0, 0, 255);
        fillEdges({viewportRight, viewportTop, s_screenWidth, viewportBottom}, 0, 0, 0, 255);
    }
}

int fried_renderer_create(int windowId, bool)
{
    if (windowId == s_bottomWindowId)
    {
        int id = fried_software_renderer_create(windowId, true);
        return id < 0 ? id : id + FRIED_SOFTWARE_ID_BASE;
    }
    if (fried_window_get_width(windowId) <= 0)
    {
        fried_set_last_error("No such window");
        return -1;
    }
    if (!s_started)
    {
        startEngine();
    }
    FriedDisplayLayout layout = fried_display_layout(s_screenWidth, s_screenHeight);
    return s_renderers.store(new Renderer{windowId, layout, 0, 0, 0, 255});
}

void fried_renderer_destroy(int rendererId)
{
    if (isSoftware(rendererId))
    {
        fried_software_renderer_destroy(softwareId(rendererId));
        return;
    }
    if (!s_renderers.get(rendererId))
    {
        return;
    }
    fried_font_release_renderer(rendererId);
    delete s_renderers.release(rendererId);
}

// The engine shows what it drew at the vertical blank after glFlush(), and
// takes no new polygons until then.
bool fried_renderer_has_vsync(int rendererId)
{
    if (isSoftware(rendererId))
    {
        return fried_software_renderer_has_vsync(softwareId(rendererId));
    }
    return s_renderers.get(rendererId) != nullptr;
}

int fried_renderer_get_width(int rendererId)
{
    if (isSoftware(rendererId))
    {
        return fried_software_renderer_get_width(softwareId(rendererId));
    }
    Renderer *renderer = s_renderers.get(rendererId);
    return renderer ? renderer->m_layout.m_width : 0;
}

int fried_renderer_get_height(int rendererId)
{
    if (isSoftware(rendererId))
    {
        return fried_software_renderer_get_height(softwareId(rendererId));
    }
    Renderer *renderer = s_renderers.get(rendererId);
    return renderer ? renderer->m_layout.m_height : 0;
}

void fried_renderer_set_draw_color(int rendererId, int r, int g, int b, int a)
{
    if (isSoftware(rendererId))
    {
        fried_software_renderer_set_draw_color(softwareId(rendererId), r, g, b, a);
        return;
    }
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

// The clear plane is opaque, and the letterbox bars go over it at present.
void fried_renderer_clear(int rendererId)
{
    if (isSoftware(rendererId))
    {
        fried_software_renderer_clear(softwareId(rendererId));
        return;
    }
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    glClearColor(renderer->m_r >> 3, renderer->m_g >> 3, renderer->m_b >> 3, 31);
}

void fried_renderer_present(int rendererId)
{
    if (isSoftware(rendererId))
    {
        fried_software_renderer_present(softwareId(rendererId));
        return;
    }
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    drawLetterboxBars(renderer->m_layout);
    glFlush(GL_TRANS_MANUALSORT);
    fried_texture_write_pending();
    s_depth = s_firstDepth;
}

void fried_renderer_draw_texture(int rendererId, int textureId, float x, float y, float width, float height)
{
    if (isSoftware(rendererId))
    {
        fried_software_renderer_draw_texture(softwareId(rendererId), softwareTextureId(textureId), x, y, width, height);
        return;
    }
    Renderer *renderer = s_renderers.get(rendererId);
    const FriedNdsTexture *texture = fried_texture_get_nds(textureId);
    if (!renderer || !texture || !beginPolygons(GL_QUADS, 255, texture))
    {
        return;
    }
    glColor(toVertexColor(255, 255, 255));
    TexelRegion region = regionOf(*texture, 0, 0, texture->m_width, texture->m_height, 0);
    drawTexturedQuad(*renderer, *texture, region, x, y, width, height, 0.0f, false, 0.0f, 0.0f);
    glEnd();
}

// Turned about the quad's centre, as SDL does with no centre given.
void fried_renderer_draw_texture_ex(int rendererId, int textureId, int srcX, int srcY, int srcWidth, int srcHeight, float x, float y, float width, float height, double angle, int flipMode)
{
    if (isSoftware(rendererId))
    {
        fried_software_renderer_draw_texture_ex(softwareId(rendererId), softwareTextureId(textureId), srcX, srcY, srcWidth, srcHeight, x, y, width, height, angle, flipMode);
        return;
    }
    Renderer *renderer = s_renderers.get(rendererId);
    const FriedNdsTexture *texture = fried_texture_get_nds(textureId);
    if (!renderer || !texture || !beginPolygons(GL_QUADS, 255, texture))
    {
        return;
    }
    glColor(toVertexColor(255, 255, 255));
    TexelRegion region = regionOf(*texture, srcX, srcY, srcWidth, srcHeight, flipMode);
    drawTexturedQuad(*renderer, *texture, region, x, y, width, height, (float)angle, false, 0.0f, 0.0f);
    glEnd();
}

// The vertex colour multiplies the texture's, which for a blank one is white.
void fried_renderer_draw_tinted(int rendererId, int textureId, const FriedQuad *quads, int count, int r, int g, int b, int a)
{
    if (isSoftware(rendererId))
    {
        fried_software_renderer_draw_tinted(softwareId(rendererId), softwareTextureId(textureId), quads, count, r, g, b, a);
        return;
    }
    Renderer *renderer = s_renderers.get(rendererId);
    const FriedNdsTexture *texture = fried_texture_get_nds(textureId);
    if (!renderer || !texture || count <= 0 || !beginPolygons(GL_QUADS, a, texture))
    {
        return;
    }
    glColor(toVertexColor(r, g, b));
    for (int index = 0; index < count; ++index)
    {
        const FriedQuad &item = quads[index];
        TexelRegion region = regionOf(*texture, item.m_srcX, item.m_srcY, item.m_srcWidth, item.m_srcHeight, 0);
        drawTexturedQuad(*renderer, *texture, region, item.m_x, item.m_y, item.m_width, item.m_height, item.m_angle, true, item.m_pivotX, item.m_pivotY);
    }
    glEnd();
}

bool fried_renderer_draw_glyphs(int rendererId, int textureId, float x, float y, const FriedGlyphBlit *glyphs, int count, int r, int g, int b, int a)
{
    if (isSoftware(rendererId))
    {
        return fried_software_renderer_draw_glyphs(softwareId(rendererId), softwareTextureId(textureId), x, y, glyphs, count, r, g, b, a);
    }
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return true;
    }
    const FriedDisplayLayout &layout = renderer->m_layout;
    if (layout.m_scaleX != 1.0f || layout.m_scaleY != 1.0f)
    {
        return false;
    }
    const FriedNdsTexture *texture = fried_texture_get_nds(textureId);
    if (!texture || count <= 0 || !beginPolygons(GL_QUADS, a, texture))
    {
        return true;
    }

    // Whole pixels throughout, since every float operation is a call into
    // the software floating point library.
    glColor(toVertexColor(r, g, b));
    int left = layout.m_viewportX + toVertexUnits(x);
    int top = layout.m_viewportY + toVertexUnits(y);
    for (int index = 0; index < count; ++index)
    {
        const FriedGlyphBlit &glyph = glyphs[index];
        int glyphLeft = left + glyph.m_offsetX;
        int glyphTop = top + glyph.m_offsetY;
        int glyphRight = glyphLeft + glyph.m_width;
        int glyphBottom = glyphTop + glyph.m_height;
        int u0 = glyph.m_srcX << 4;
        int v0 = glyph.m_srcY << 4;
        int u1 = (glyph.m_srcX + glyph.m_width) << 4;
        int v1 = (glyph.m_srcY + glyph.m_height) << 4;
        vertex(glyphLeft, glyphTop, u0, v0, nextDepth());
        vertexAtSameDepth(glyphRight, glyphTop, u1, v0);
        vertexAtSameDepth(glyphRight, glyphBottom, u1, v1);
        vertexAtSameDepth(glyphLeft, glyphBottom, u0, v1);
    }
    glEnd();
    return true;
}

void fried_renderer_fill_rect(int rendererId, float x, float y, float width, float height)
{
    if (isSoftware(rendererId))
    {
        fried_software_renderer_fill_rect(softwareId(rendererId), x, y, width, height);
        return;
    }
    Renderer *renderer = s_renderers.get(rendererId);
    if (renderer)
    {
        fillEdges(outputEdges(renderer->m_layout, x, y, width, height), renderer->m_r, renderer->m_g, renderer->m_b, renderer->m_a);
    }
}

// One pixel wide and inside the rectangle, as SDL_RenderDrawRect() draws it.
void fried_renderer_draw_rect(int rendererId, float x, float y, float width, float height)
{
    if (isSoftware(rendererId))
    {
        fried_software_renderer_draw_rect(softwareId(rendererId), x, y, width, height);
        return;
    }
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer || width <= 0.0f || height <= 0.0f)
    {
        return;
    }
    Edges outer = outputEdges(renderer->m_layout, x, y, width, height);
    Edges inner = outputEdges(renderer->m_layout, x + 1.0f, y + 1.0f, width - 2.0f, height - 2.0f);
    if (isEmpty(outer) || !beginPolygons(GL_QUADS, renderer->m_a, nullptr))
    {
        return;
    }
    glColor(toVertexColor(renderer->m_r, renderer->m_g, renderer->m_b));
    quad({outer.m_left, outer.m_top, outer.m_right, inner.m_top}, 0, 0, 0, 0);
    quad({outer.m_left, inner.m_bottom, outer.m_right, outer.m_bottom}, 0, 0, 0, 0);
    quad({outer.m_left, inner.m_top, inner.m_left, inner.m_bottom}, 0, 0, 0, 0);
    quad({inner.m_right, inner.m_top, outer.m_right, inner.m_bottom}, 0, 0, 0, 0);
    glEnd();
}

void fried_renderer_fill_triangles(int rendererId, const double *points, const int *argbColors, int triangleCount)
{
    if (isSoftware(rendererId))
    {
        fried_software_renderer_fill_triangles(softwareId(rendererId), points, argbColors, triangleCount);
        return;
    }
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    const FriedDisplayLayout &layout = renderer->m_layout;
    for (int index = 0; index < triangleCount; ++index)
    {
        uint32_t argb = (uint32_t)argbColors[index];
        if (!beginPolygons(GL_TRIANGLES, (int)(argb >> 24), nullptr))
        {
            continue;
        }
        glColor(toVertexColor((int)((argb >> 16) & 0xff), (int)((argb >> 8) & 0xff), (int)(argb & 0xff)));
        const double *corners = points + index * 6;
        int depth = nextDepth();
        for (int corner = 0; corner < 3; ++corner)
        {
            Corner output = {layout.m_viewportX + (float)corners[corner * 2] * layout.m_scaleX, layout.m_viewportY + (float)corners[corner * 2 + 1] * layout.m_scaleY};
            vertex(output, 0, 0, depth);
        }
        glEnd();
    }
}

void fried_renderer_window_to_logical(int windowId, int x, int y, int &logicalX, int &logicalY)
{
    if (windowId == s_bottomWindowId)
    {
        fried_software_renderer_window_to_logical(windowId, x, y, logicalX, logicalY);
        return;
    }
    FriedDisplayLayout layout = fried_display_layout(s_screenWidth, s_screenHeight);
    logicalX = (int)std::floor((x - layout.m_viewportX) / layout.m_scaleX);
    logicalY = (int)std::floor((y - layout.m_viewportY) / layout.m_scaleY);
}

void fried_renderer_touch_to_logical(int windowId, float x, float y, int &logicalX, int &logicalY)
{
    if (windowId == s_bottomWindowId)
    {
        fried_software_renderer_touch_to_logical(windowId, x, y, logicalX, logicalY);
        return;
    }
    FriedDisplayLayout layout = fried_display_layout(s_screenWidth, s_screenHeight);
    logicalX = std::clamp((int)(x * layout.m_width), 0, std::max(0, layout.m_width - 1));
    logicalY = std::clamp((int)(y * layout.m_height), 0, std::max(0, layout.m_height - 1));
}

float fried_renderer_get_pixel_scale(int rendererId)
{
    if (isSoftware(rendererId))
    {
        return fried_software_renderer_get_pixel_scale(softwareId(rendererId));
    }
    Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return 1.0f;
    }
    return std::min(renderer->m_layout.m_scaleX, renderer->m_layout.m_scaleY);
}

// The software renderer releases its fonts when it is destroyed, by its own id.
void fried_software_font_release_renderer(int rendererId)
{
    fried_font_release_renderer(rendererId + FRIED_SOFTWARE_ID_BASE);
}
