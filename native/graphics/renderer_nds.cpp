#include "math/real.h"
#include "graphics/renderer.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/display.h"
#include "graphics/font.h"
#include "graphics/mesh.h"
#include "graphics/software_backend_nds.h"
#include "graphics/texture.h"
#include "math/fixed_point.h"
#include "platform/window.h"
#include "scene/tilemap.h"
#include "scene/transform2d.h"

#include <nds.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>

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
//
// Meshes are turned, lit and depth tested by the engine itself, under a
// projection of their own that puts them in perspective on the same screen,
// with their depth in a band of steps nearer than whatever came before them,
// so they sit in the draw order as one more draw. Meshes drawn one after
// another with the same view share a band and are depth tested against each
// other within it. The next 2D draw puts the screen's projection back, and
// takes its depth from past the band.

namespace
{
    struct Renderer
    {
        int m_windowId;
        FriedDisplayLayout m_layout;
        bool m_hasUnitScale;
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
    constexpr int s_projectionDepth = 4096;
    constexpr int s_firstDepth = -4000;
    constexpr int s_lastDepth = 4000;
    int s_depth = s_firstDepth;

    // 0 is the clear plane's, which no polygon blends against anyway.
    constexpr int s_firstTranslucentId = 1;
    constexpr int s_lastTranslucentId = 62;
    int s_translucentId = s_firstTranslucentId;

    // Keeps a vertex within what 16 bits hold.
    constexpr float s_maxCoordinate = 4096.0f;

    // What a band of meshes is drawn with: the placement's numbers from the
    // camera's on, and the 2D camera's.
    constexpr int s_meshViewSize = FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X;

    struct MeshView
    {
        fried_real m_placement[s_meshViewSize];
        double m_hasCamera;
        double m_zoom;
        double m_cameraX;
        double m_cameraY;
    };

    // The projection turns y over, from up in the camera's space to down on
    // the screen, so a polygon that faces the camera goes round the other
    // way to the engine, which takes it for the back of one.
    constexpr uint32_t s_meshCulling = POLY_CULL_FRONT;

    constexpr int s_meshBandSteps = 1024;
    constexpr double s_smallestNear = 1.0 / 4096.0;
    // The projection is scaled up by this, which the division by w takes out
    // again, so its small terms keep more of their bits in fixed point.
    constexpr double s_meshClipScale = 64.0;
    // Past this from the camera a mesh's position times the projection
    // overflows a 20.12 fixed point number, so it is not drawn.
    constexpr int64_t s_farthestMesh = (int64_t)4096 << 12;
    // 360 degrees in 20.12 fixed point times this, shifted down by 24, is
    // DEGREES_IN_CIRCLE.
    constexpr int64_t s_angleFactor = 372827;

    bool s_drawingMeshes = false;
    MeshView s_meshView;
    // The camera's position in 20.12 fixed point.
    int64_t s_meshCameraX = 0;
    int64_t s_meshCameraY = 0;
    int64_t s_meshCameraZ = 0;
    // From 0 to 32, how much of a polygon's color it gives out unlit.
    int s_meshAmbient = 0;

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
        glOrthof32(0, s_screenWidth, s_screenHeight, 0, -s_projectionDepth, s_projectionDepth);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        s_started = true;
    }

    // The coordinate rounded half away from zero and kept within what a vertex
    // holds, worked out from the float's bits: each comparison and addition on
    // a float is a call into software floating point here. Past 4096 in size
    // it saturates, and so would a value a float cannot place.
    int toVertexUnits(float coordinate)
    {
        constexpr int exponentOfHalf = 126;
        constexpr int exponentOfMaximum = 139;
        uint32_t bits;
        std::memcpy(&bits, &coordinate, sizeof bits);
        int exponent = (int)((bits >> 23) & 0xff);
        int magnitude;
        if (exponent < exponentOfHalf)
        {
            magnitude = 0;
        }
        else if (exponent >= exponentOfMaximum)
        {
            magnitude = (int)s_maxCoordinate;
        }
        else
        {
            uint32_t mantissa = (bits & 0x7fffff) | 0x800000;
            int shift = 150 - exponent;
            magnitude = (int)((mantissa + (1u << (shift - 1))) >> shift);
        }
        return (bits >> 31) ? -magnitude : magnitude;
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
    int outputEdge(float logical, float scale, int offset, bool hasUnitScale)
    {
        return offset + toVertexUnits(hasUnitScale ? logical : logical * scale);
    }

    Edges outputEdges(const Renderer &renderer, float x, float y, float width, float height)
    {
        const FriedDisplayLayout &layout = renderer.m_layout;
        bool hasUnitScale = renderer.m_hasUnitScale;
        return {
            outputEdge(x, layout.m_scaleX, layout.m_viewportX, hasUnitScale),
            outputEdge(y, layout.m_scaleY, layout.m_viewportY, hasUnitScale),
            outputEdge(x + width, layout.m_scaleX, layout.m_viewportX, hasUnitScale),
            outputEdge(y + height, layout.m_scaleY, layout.m_viewportY, hasUnitScale),
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

    // Puts the screen's projection back after a band of meshes.
    ITCM_CODE void leaveMeshes()
    {
        if (!s_drawingMeshes)
        {
            return;
        }
        glMatrixMode(GL_PROJECTION);
        glPopMatrix(1);
        glMatrixMode(GL_MODELVIEW);
        glPopMatrix(1);
        s_drawingMeshes = false;
    }

    // An alpha of zero is how the engine asks for a wireframe, so nothing
    // that faint is drawn.
    ITCM_CODE bool startPolygons(GL_GLBEGIN_ENUM kind, int alpha, const FriedNdsTexture *texture, uint32_t format)
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
        glPolyFmt(POLY_ALPHA(polygonAlpha) | POLY_ID(id) | format);
        glBindTexture(0, texture ? texture->m_name : 0);
        glBegin(kind);
        return true;
    }

    // Sends packed commands to the geometry engine's FIFO by DMA, and waits
    // until it has taken them all, as the direct writes that follow must come
    // after them. FIFO DMA does not run beside another channel.
    void sendCommands(const uint32_t *words, int count)
    {
        constexpr int s_channels = 4;
        constexpr uintptr_t s_fifoAddress = 0x4000400;
        for (int channel = 0; channel < s_channels; ++channel)
        {
            while (DMA_CR(channel) & DMA_BUSY)
            {
            }
        }
        DMA_SRC(0) = (uint32_t)words;
        DMA_DEST(0) = s_fifoAddress;
        DMA_CR(0) = DMA_FIFO | (uint32_t)count;
        while (DMA_CR(0) & DMA_BUSY)
        {
        }
    }

    // Starts the polygons of one 2D draw, at one alpha and with one texture
    // or none.
    ITCM_CODE bool beginPolygons(GL_GLBEGIN_ENUM kind, int alpha, const FriedNdsTexture *texture)
    {
        leaveMeshes();
        return startPolygons(kind, alpha, texture, POLY_CULL_NONE);
    }

    ITCM_CODE int nextDepth()
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

    ITCM_CODE void quad(const Edges &edges, int u0, int v0, int u1, int v1)
    {
        vertex(edges.m_left, edges.m_top, u0, v0, nextDepth());
        vertexAtSameDepth(edges.m_right, edges.m_top, u1, v0);
        vertexAtSameDepth(edges.m_right, edges.m_bottom, u1, v1);
        vertexAtSameDepth(edges.m_left, edges.m_bottom, u0, v1);
    }

    // With no texture bound the engine ignores texel coordinates, so none are sent.
    ITCM_CODE void plainQuad(const Edges &edges)
    {
        glVertex3v16((v16)edges.m_left, (v16)edges.m_top, (v16)nextDepth());
        GFX_VERTEX_XY = ((uint32_t)edges.m_top << 16) | ((uint32_t)edges.m_right & 0xffff);
        GFX_VERTEX_XY = ((uint32_t)edges.m_bottom << 16) | ((uint32_t)edges.m_right & 0xffff);
        GFX_VERTEX_XY = ((uint32_t)edges.m_bottom << 16) | ((uint32_t)edges.m_left & 0xffff);
    }

    void fillEdges(const Edges &edges, int r, int g, int b, int a)
    {
        if (isEmpty(edges) || !beginPolygons(GL_QUADS, a, nullptr))
        {
            return;
        }
        glColor(toVertexColor(r, g, b));
        plainQuad(edges);
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

    ITCM_CODE TexelRegion regionOf(const FriedNdsTexture &texture, int srcX, int srcY, int srcWidth, int srcHeight, int flipMode)
    {
        int shift = texture.m_downscaleShift;
        TexelRegion region = {(srcX << 4) >> shift, (srcY << 4) >> shift, ((srcX + srcWidth) << 4) >> shift, ((srcY + srcHeight) << 4) >> shift};
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
        Edges edges = outputEdges(renderer, x, y, width, height);
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

    // One pixel wide, inside the outer edges, from four rectangles of a polygon list that is already open.
    ITCM_CODE void outlineQuads(const Edges &outer, const Edges &inner, int r, int g, int b)
    {
        glColor(toVertexColor(r, g, b));
        plainQuad({outer.m_left, outer.m_top, outer.m_right, inner.m_top});
        plainQuad({outer.m_left, inner.m_bottom, outer.m_right, outer.m_bottom});
        plainQuad({outer.m_left, inner.m_top, inner.m_left, inner.m_bottom});
        plainQuad({inner.m_right, inner.m_top, outer.m_right, inner.m_bottom});
    }

    void outlineEdges(const Edges &outer, const Edges &inner, int r, int g, int b, int a)
    {
        if (isEmpty(outer) || !beginPolygons(GL_QUADS, a, nullptr))
        {
            return;
        }
        outlineQuads(outer, inner, r, g, b);
        glEnd();
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

    int toF32(double value)
    {
        return (int)(value * 4096.0);
    }

    int toV10(double value)
    {
        return std::clamp((int)(value * 512.0), -512, 511);
    }

    // DEGREES_IN_CIRCLE is a whole turn, and any number of turns wraps.
    int toAngle(double degrees)
    {
        return (int)(((fried_to_fixed(degrees, 12) * s_angleFactor) >> 24) & (DEGREES_IN_CIRCLE - 1));
    }

    int toAngle(float degrees)
    {
        return (int)(((fried_to_fixed_single(degrees, 12) * s_angleFactor) >> 24) & (DEGREES_IN_CIRCLE - 1));
    }

    int toInverseAngle(double degrees)
    {
        return (DEGREES_IN_CIRCLE - toAngle(degrees)) & (DEGREES_IN_CIRCLE - 1);
    }

    // Word by word, as newlib's memcmp() goes a byte at a time.
    bool isSameWords(const void *a, const void *b, size_t bytes)
    {
        const uint32_t *aWords = (const uint32_t *)a;
        const uint32_t *bWords = (const uint32_t *)b;
        for (size_t index = 0; index < bytes / 4; ++index)
        {
            if (aWords[index] != bWords[index])
            {
                return false;
            }
        }
        return true;
    }

    bool isSameView(const fried_real *placement, bool hasCamera, double zoom, double cameraX, double cameraY)
    {
        if (!isSameWords(placement + FRIED_MESH_CAMERA_X, s_meshView.m_placement, sizeof s_meshView.m_placement))
        {
            return false;
        }
        if (!hasCamera)
        {
            return s_meshView.m_hasCamera == 0.0;
        }
        double camera[] = {1.0, zoom, cameraX, cameraY};
        return isSameWords(camera, &s_meshView.m_hasCamera, sizeof camera);
    }

    // Starts a band of meshes, or carries on with the one before when nothing
    // has been drawn in 2D since and the view is the same. A mesh at a depth
    // of z from the camera lands farthest + (nearest - farthest) * near / z
    // steps in, which is nearest at the near plane and farthest only
    // infinitely far away, so no far plane is needed to keep it in the band.
    void enterMeshes(const fried_real *placement, bool hasCamera, double zoom, double cameraX, double cameraY, const FriedDisplayLayout &layout)
    {
        if (s_drawingMeshes && isSameView(placement, hasCamera, zoom, cameraX, cameraY))
        {
            return;
        }
        leaveMeshes();
        MeshView &view = s_meshView;
        std::memcpy(view.m_placement, placement + FRIED_MESH_CAMERA_X, sizeof view.m_placement);
        view.m_hasCamera = hasCamera ? 1.0 : 0.0;
        view.m_zoom = hasCamera ? zoom : 0.0;
        view.m_cameraX = hasCamera ? cameraX : 0.0;
        view.m_cameraY = hasCamera ? cameraY : 0.0;
        int farthest = std::min(s_depth + 1, s_lastDepth);
        int nearest = std::min(s_depth + s_meshBandSteps, s_lastDepth);
        s_depth = nearest;

        auto number = [&view](FriedMeshPlacement index) -> double { return view.m_placement[index - FRIED_MESH_CAMERA_X]; };
        s_meshCameraX = fried_to_fixed(number(FRIED_MESH_CAMERA_X), 12);
        s_meshCameraY = fried_to_fixed(number(FRIED_MESH_CAMERA_Y), 12);
        s_meshCameraZ = fried_to_fixed(number(FRIED_MESH_CAMERA_Z), 12);

        // A logical pixel goes to (x - cameraX) * zoom + width / 2 under a 2D
        // camera, as DrawQueue moves the points of triangles.
        double scaleOfZoom = hasCamera ? zoom : 1.0;
        double shiftX = hasCamera ? layout.m_width / 2.0 - cameraX * zoom : 0.0;
        double shiftY = hasCamera ? layout.m_height / 2.0 - cameraY * zoom : 0.0;
        double viewportHeight = number(FRIED_MESH_VIEWPORT_HEIGHT);
        double focalLength = scaleOfZoom * (viewportHeight / 2.0) / std::tan(number(FRIED_MESH_FIELD_OF_VIEW) * M_PI / 360.0);
        double logicalCenterX = number(FRIED_MESH_VIEWPORT_X) + number(FRIED_MESH_VIEWPORT_WIDTH) / 2.0;
        double logicalCenterY = number(FRIED_MESH_VIEWPORT_Y) + viewportHeight / 2.0;
        double centerX = layout.m_viewportX + layout.m_scaleX * (scaleOfZoom * logicalCenterX + shiftX);
        double centerY = layout.m_viewportY + layout.m_scaleY * (scaleOfZoom * logicalCenterY + shiftY);
        double near = std::max(number(FRIED_MESH_NEAR), s_smallestNear);

        // From the camera's space to an output pixel times its z, and from
        // there to clip space as the screen's projection takes a pixel.
        double scale = s_meshClipScale;
        m4x4 projection = {};
        projection.m[0] = toF32(scale * 2.0 * layout.m_scaleX * focalLength / s_screenWidth);
        projection.m[5] = toF32(scale * 2.0 * layout.m_scaleY * focalLength / s_screenHeight);
        projection.m[8] = toF32(scale * (2.0 * centerX / s_screenWidth - 1.0));
        projection.m[9] = toF32(scale * (1.0 - 2.0 * centerY / s_screenHeight));
        projection.m[10] = toF32(-scale * farthest / s_projectionDepth);
        projection.m[11] = toF32(scale);
        projection.m[14] = toF32(-scale * (nearest - farthest) * near / s_projectionDepth);
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadMatrix4x4(&projection);
        glMatrixMode(GL_MODELVIEW);

        // The camera's turn undone, which every mesh of the band is drawn
        // under, and which turns the light into the camera's space as it is
        // set. The camera is turned about z, then x, then y, so undoing it
        // goes the other way round, and each call lands on the right.
        glPushMatrix();
        glLoadIdentity();
        glRotateZi(toInverseAngle(number(FRIED_MESH_CAMERA_ROTATION_Z)));
        glRotateXi(toInverseAngle(number(FRIED_MESH_CAMERA_ROTATION_X)));
        glRotateYi(toInverseAngle(number(FRIED_MESH_CAMERA_ROTATION_Y)));

        // Set under the camera's turn, so the light points the same way in
        // the camera's space whatever a mesh is turned by.
        // A polygon gives out its ambient share of its color unlit, and the
        // light the rest as it faces into it, as MeshPass shades one.
        double ambient = std::clamp(number(FRIED_MESH_AMBIENT), 0.0, 1.0);
        double lightX = number(FRIED_MESH_LIGHT_X);
        double lightY = number(FRIED_MESH_LIGHT_Y);
        double lightZ = number(FRIED_MESH_LIGHT_Z);
        double length = std::sqrt(lightX * lightX + lightY * lightY + lightZ * lightZ);
        if (length > 0.0)
        {
            lightX /= length;
            lightY /= length;
            lightZ /= length;
        }
        int level = (int)((1.0 - ambient) * 31.0 + 0.5);
        glLight(0, RGB15(level, level, level), (v10)toV10(lightX), (v10)toV10(lightY), (v10)toV10(lightZ));
        s_meshAmbient = (int)(ambient * 32.0 + 0.5);

        s_drawingMeshes = true;
    }

}

namespace
{
    constexpr int s_recordInts = 8;
    constexpr int s_recordFloats = 5;
    constexpr int s_textureRecord = 0;
    constexpr int s_fillRecord = 1;
    constexpr int s_outlineRecord = 2;
    constexpr int s_cameraRecord = 3;
    constexpr int s_scaledTextureRecord = 4;
    constexpr int s_slotTextureRecord = 5;
    constexpr int s_tilemapRecord = 6;
    constexpr int s_fixedOne = 1 << 16;

    // What places a record: the camera and the display's layout, in 16.16 fixed point, worked out from the floats' bits so no float operation is done for it.
    struct BatchView
    {
        bool m_hasCamera;
        bool m_hasUnitScale;
        int64_t m_zoom;
        int64_t m_offsetX;
        int64_t m_offsetY;
        int64_t m_scaleX;
        int64_t m_scaleY;
        int m_viewportX;
        int m_viewportY;
    };

    // Rounded half away from zero to a pixel, and kept within what a vertex holds.
    ITCM_CODE int roundToPixels(int64_t value)
    {
        int64_t magnitude = ((value < 0 ? -value : value) + (s_fixedOne >> 1)) >> 16;
        if (magnitude > (int64_t)s_maxCoordinate)
        {
            magnitude = (int64_t)s_maxCoordinate;
        }
        return value < 0 ? -(int)magnitude : (int)magnitude;
    }

    ITCM_CODE int batchEdgeX(const BatchView &view, int64_t logical)
    {
        return view.m_viewportX + roundToPixels(view.m_hasUnitScale ? logical : (logical * view.m_scaleX) >> 16);
    }

    ITCM_CODE int batchEdgeY(const BatchView &view, int64_t logical)
    {
        return view.m_viewportY + roundToPixels(view.m_hasUnitScale ? logical : (logical * view.m_scaleY) >> 16);
    }

    // A record's rectangle on the logical screen, in 16.16.
    struct LogicalRect
    {
        int64_t m_x;
        int64_t m_y;
        int64_t m_width;
        int64_t m_height;
    };

    ITCM_CODE LogicalRect placeOf(const BatchView &view, int64_t x, int64_t y, int64_t width, int64_t height)
    {
        LogicalRect rect = {x, y, width, height};
        if (view.m_hasCamera)
        {
            rect.m_x = ((rect.m_x * view.m_zoom) >> 16) + view.m_offsetX;
            rect.m_y = ((rect.m_y * view.m_zoom) >> 16) + view.m_offsetY;
            rect.m_width = (rect.m_width * view.m_zoom) >> 16;
            rect.m_height = (rect.m_height * view.m_zoom) >> 16;
        }
        return rect;
    }

    ITCM_CODE LogicalRect placeOf(const BatchView &view, const float *values, int64_t width, int64_t height)
    {
        return placeOf(view, fried_to_fixed_single(values[0], 16), fried_to_fixed_single(values[1], 16), width, height);
    }

    ITCM_CODE Edges edgesOf(const BatchView &view, const LogicalRect &rect)
    {
        return {batchEdgeX(view, rect.m_x), batchEdgeY(view, rect.m_y), batchEdgeX(view, rect.m_x + rect.m_width), batchEdgeY(view, rect.m_y + rect.m_height)};
    }

    bool isZero(float value)
    {
        uint32_t bits;
        std::memcpy(&bits, &value, sizeof bits);
        return (bits << 1) == 0;
    }

    // The corners turned about the middle of the edges, in half pixels so the middle needs no division.
    ITCM_CODE void rotatedQuad(const Edges &edges, const TexelRegion &region, int angle)
    {
        int cosine = cosLerp((s16)angle);
        int sine = sinLerp((s16)angle);
        int pivotX = edges.m_left + edges.m_right;
        int pivotY = edges.m_top + edges.m_bottom;
        const int cornerX[4] = {edges.m_left, edges.m_right, edges.m_right, edges.m_left};
        const int cornerY[4] = {edges.m_top, edges.m_top, edges.m_bottom, edges.m_bottom};
        int turnedX[4];
        int turnedY[4];
        for (int index = 0; index < 4; ++index)
        {
            int offsetX = cornerX[index] * 2 - pivotX;
            int offsetY = cornerY[index] * 2 - pivotY;
            turnedX[index] = (pivotX + ((offsetX * cosine - offsetY * sine) >> 12) + 1) >> 1;
            turnedY[index] = (pivotY + ((offsetX * sine + offsetY * cosine) >> 12) + 1) >> 1;
        }
        int depth = nextDepth();
        vertex(turnedX[0], turnedY[0], region.m_u0, region.m_v0, depth);
        vertexAtSameDepth(turnedX[1], turnedY[1], region.m_u1, region.m_v0);
        vertexAtSameDepth(turnedX[2], turnedY[2], region.m_u1, region.m_v1);
        vertexAtSameDepth(turnedX[3], turnedY[3], region.m_u0, region.m_v1);
    }

    // The list of quads a run of draws shares. Quads that are opaque and of one texture, or of none, are drawn under one polygon format, texture and list; a translucent one takes a polygon ID of its own, so it never shares.
    struct PolygonList
    {
        bool m_isOpen;
        const FriedNdsTexture *m_texture;
    };

    ITCM_CODE void endList(PolygonList &list)
    {
        if (list.m_isOpen)
        {
            glEnd();
            list.m_isOpen = false;
        }
    }

    ITCM_CODE bool startList(PolygonList &list, const FriedNdsTexture *texture, int alpha)
    {
        bool isShareable = alpha == 255 && !(texture && texture->m_translucent);
        if (list.m_isOpen && isShareable && list.m_texture == texture)
        {
            return true;
        }
        endList(list);
        if (!beginPolygons(GL_QUADS, alpha, texture))
        {
            return false;
        }
        list.m_isOpen = isShareable;
        list.m_texture = texture;
        return true;
    }

    // Closes what startList() opened, unless a following draw may carry on in it.
    ITCM_CODE void finishDraw(const PolygonList &list)
    {
        if (!list.m_isOpen)
        {
            glEnd();
        }
    }

    // A texture record's quad, straight unless it is turned about its middle.
    ITCM_CODE void drawTextureRecord(PolygonList &list, const BatchView &view, const int *record, const LogicalRect &rect, bool isTurned, int angle)
    {
        const FriedNdsTexture *texture = fried_texture_get_nds(record[1]);
        if (!texture || !startList(list, texture, 255))
        {
            return;
        }
        glColor(toVertexColor(255, 255, 255));
        Edges edges = edgesOf(view, rect);
        TexelRegion region = regionOf(*texture, record[2], record[3], record[4], record[5], record[6]);
        if (isTurned)
        {
            rotatedQuad(edges, region, angle);
        }
        else
        {
            quad(edges, region.m_u0, region.m_v0, region.m_u1, region.m_v1);
        }
        finishDraw(list);
    }

    // A sprite placed by its transform slot, whose numbers are already in the units the record is drawn with.
    ITCM_CODE void drawSlotRecord(PolygonList &list, const BatchView &view, const int *record)
    {
        const FriedTransform2DFixed *world = fried_transform2d_world_fixed(record[7]);
        int64_t width = (world->m_scaleX * record[4]) >> 16;
        int64_t height = (world->m_scaleY * record[5]) >> 16;
        LogicalRect rect = placeOf(view, world->m_x, world->m_y, width, height);
        int angle = (int)((((int64_t)world->m_rotation * s_angleFactor) >> 24) & (DEGREES_IN_CIRCLE - 1));
        drawTextureRecord(list, view, record, rect, world->m_rotation != 0, angle);
    }

    constexpr int s_tileEdgeCapacity = 96;

    // The tiles one at a time, each placed and drawn as a texture record: for a tileset that is translucent, or a view of more tiles than the edge tables hold.
    ITCM_CODE void drawTilesOneByOne(PolygonList &list, const BatchView &view, const int *record, const FriedTilemap *map, const LogicalRect &origin, int firstColumn, int firstRow, int endColumn, int endRow)
    {
        int tileRecord[s_recordInts] = {s_textureRecord, record[1], 0, 0, map->m_tileWidth, map->m_tileHeight, 0, 0};
        for (int row = firstRow; row < endRow; ++row)
        {
            const uint16_t *cells = map->m_cells + row * map->m_width;
            int64_t top = origin.m_y + row * origin.m_height;
            for (int column = firstColumn; column < endColumn; ++column)
            {
                int cell = cells[column];
                if (cell == 0)
                {
                    continue;
                }
                int tile = cell - 1;
                tileRecord[2] = (tile % map->m_columns) * map->m_tileWidth;
                tileRecord[3] = (tile / map->m_columns) * map->m_tileHeight;
                drawTextureRecord(list, view, tileRecord, {origin.m_x + column * origin.m_width, top, origin.m_width, origin.m_height}, false, 0);
            }
        }
    }

    // The tiles of a map that the screen shows, each a quad of its own. Every tile's edges are the same two numbers as its neighbours', so no seam opens between them at any scale. A map is not turned.
    ITCM_CODE void drawTilemapRecord(PolygonList &list, const BatchView &view, const int *record, int64_t screenWidth, int64_t screenHeight)
    {
        const FriedTilemap *map = fried_tilemap_get(record[2]);
        if (map == nullptr)
        {
            return;
        }
        const FriedTransform2DFixed *world = fried_transform2d_world_fixed(record[7]);
        LogicalRect origin = placeOf(view, world->m_x, world->m_y, (world->m_scaleX * map->m_tileWidth) >> 16, (world->m_scaleY * map->m_tileHeight) >> 16);
        const int64_t tileWidth = origin.m_width;
        const int64_t tileHeight = origin.m_height;
        if (tileWidth <= 0 || tileHeight <= 0)
        {
            return;
        }
        int firstColumn = origin.m_x >= 0 ? 0 : (int)((-origin.m_x) / tileWidth);
        int firstRow = origin.m_y >= 0 ? 0 : (int)((-origin.m_y) / tileHeight);
        int64_t spanX = screenWidth - origin.m_x;
        int64_t spanY = screenHeight - origin.m_y;
        int endColumn = spanX <= 0 ? 0 : (int)((spanX + tileWidth - 1) / tileWidth);
        int endRow = spanY <= 0 ? 0 : (int)((spanY + tileHeight - 1) / tileHeight);
        endColumn = endColumn > map->m_width ? map->m_width : endColumn;
        endRow = endRow > map->m_height ? map->m_height : endRow;

        // An opaque tileset is one list, one texture and one color for every tile, and each edge is worked out once for the row or the column that shares it.
        const FriedNdsTexture *texture = fried_texture_get_nds(record[1]);
        const int columnCount = endColumn - firstColumn;
        const int rowCount = endRow - firstRow;
        if (!texture || columnCount <= 0 || rowCount <= 0 || columnCount > s_tileEdgeCapacity || rowCount > s_tileEdgeCapacity)
        {
            drawTilesOneByOne(list, view, record, map, origin, firstColumn, firstRow, endColumn, endRow);
            return;
        }
        if (texture->m_translucent)
        {
            drawTilesOneByOne(list, view, record, map, origin, firstColumn, firstRow, endColumn, endRow);
            return;
        }
        int columnEdges[s_tileEdgeCapacity + 1];
        int rowEdges[s_tileEdgeCapacity + 1];
        for (int at = 0; at <= columnCount; ++at)
        {
            columnEdges[at] = batchEdgeX(view, origin.m_x + (firstColumn + at) * tileWidth);
        }
        for (int at = 0; at <= rowCount; ++at)
        {
            rowEdges[at] = batchEdgeY(view, origin.m_y + (firstRow + at) * tileHeight);
        }
        if (!startList(list, texture, 255))
        {
            return;
        }
        glColor(toVertexColor(255, 255, 255));
        for (int row = firstRow; row < endRow; ++row)
        {
            const uint16_t *cells = map->m_cells + row * map->m_width;
            const int top = rowEdges[row - firstRow];
            const int bottom = rowEdges[row - firstRow + 1];
            for (int column = firstColumn; column < endColumn; ++column)
            {
                int cell = cells[column];
                if (cell == 0)
                {
                    continue;
                }
                int tile = cell - 1;
                TexelRegion region = regionOf(*texture, (tile % map->m_columns) * map->m_tileWidth, (tile / map->m_columns) * map->m_tileHeight, map->m_tileWidth, map->m_tileHeight, 0);
                quad({columnEdges[column - firstColumn], top, columnEdges[column - firstColumn + 1], bottom}, region.m_u0, region.m_v0, region.m_u1, region.m_v1);
            }
        }
        finishDraw(list);
    }

    ITCM_CODE __attribute__((noinline)) void drawBatchRecords(const Renderer &renderer, const int *ints, const float *floats, int count)
    {
        const FriedDisplayLayout &layout = renderer.m_layout;
        BatchView view = {false, renderer.m_hasUnitScale, s_fixedOne, 0, 0, fried_to_fixed_single(layout.m_scaleX, 16), fried_to_fixed_single(layout.m_scaleY, 16),
                          layout.m_viewportX, layout.m_viewportY};
        int64_t halfWidth = (int64_t)layout.m_width << 15;
        int64_t halfHeight = (int64_t)layout.m_height << 15;
        PolygonList list = {false, nullptr};

        for (int index = 0; index < count; ++index)
        {
            const int *record = ints + index * s_recordInts;
            const float *values = floats + index * s_recordFloats;
            int kind = record[0];
            if (kind == s_cameraRecord)
            {
                view.m_hasCamera = record[7] != 0;
                if (view.m_hasCamera)
                {
                    view.m_zoom = fried_to_fixed_single(values[0], 16);
                    view.m_offsetX = halfWidth - ((fried_to_fixed_single(values[1], 16) * view.m_zoom) >> 16);
                    view.m_offsetY = halfHeight - ((fried_to_fixed_single(values[2], 16) * view.m_zoom) >> 16);
                }
                continue;
            }

            if (kind == s_slotTextureRecord)
            {
                drawSlotRecord(list, view, record);
                continue;
            }

            if (kind == s_tilemapRecord)
            {
                drawTilemapRecord(list, view, record, halfWidth * 2, halfHeight * 2);
                continue;
            }

            // A scale takes 32 bits of fraction so that a size times it is cut at the same place as the size worked out whole.
            int64_t width = kind == s_scaledTextureRecord ? (fried_to_fixed_single(values[2], 32) * record[4]) >> 16 : fried_to_fixed_single(values[2], 16);
            int64_t height = kind == s_scaledTextureRecord ? (fried_to_fixed_single(values[3], 32) * record[5]) >> 16 : fried_to_fixed_single(values[3], 16);
            LogicalRect rect = placeOf(view, values, width, height);
            if (kind == s_textureRecord || kind == s_scaledTextureRecord)
            {
                bool isTurned = !isZero(values[4]);
                drawTextureRecord(list, view, record, rect, isTurned, isTurned ? toAngle(values[4]) : 0);
                continue;
            }

            int color = record[1];
            int r = (color >> 16) & 0xff;
            int g = (color >> 8) & 0xff;
            int b = color & 0xff;
            int a = (color >> 24) & 0xff;
            if (kind == s_fillRecord)
            {
                Edges edges = edgesOf(view, rect);
                if (!isEmpty(edges) && startList(list, nullptr, a))
                {
                    glColor(toVertexColor(r, g, b));
                    plainQuad(edges);
                    finishDraw(list);
                }
            }
            else if (kind == s_outlineRecord && rect.m_width > 0 && rect.m_height > 0)
            {
                Edges outer = edgesOf(view, rect);
                Edges inner = edgesOf(view, {rect.m_x + s_fixedOne, rect.m_y + s_fixedOne, rect.m_width - 2 * s_fixedOne, rect.m_height - 2 * s_fixedOne});
                if (!isEmpty(outer) && startList(list, nullptr, a))
                {
                    outlineQuads(outer, inner, r, g, b);
                    finishDraw(list);
                }
            }
        }
        endList(list);
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
    return s_renderers.store(new Renderer{windowId, layout, layout.m_scaleX == 1.0f && layout.m_scaleY == 1.0f, 0, 0, 0, 255});
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
    leaveMeshes();
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

// Turned about the quad's center, as SDL does with no center given.
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

// The vertex color multiplies the texture's, which for a blank one is white.
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
    const FriedNdsTexture *texture = fried_texture_get_nds(textureId);
    if (!texture || count <= 0 || !beginPolygons(GL_QUADS, a, texture))
    {
        return true;
    }

    // Whole pixels from here on, since every float operation is a call into
    // the software floating point library: only the line's origin is placed
    // by the display's scale, and its glyphs are already in output pixels.
    glColor(toVertexColor(r, g, b));
    int left = outputEdge(x, layout.m_scaleX, layout.m_viewportX, renderer->m_hasUnitScale);
    int top = outputEdge(y, layout.m_scaleY, layout.m_viewportY, renderer->m_hasUnitScale);
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
        fillEdges(outputEdges(*renderer, x, y, width, height), renderer->m_r, renderer->m_g, renderer->m_b, renderer->m_a);
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
    Edges outer = outputEdges(*renderer, x, y, width, height);
    Edges inner = outputEdges(*renderer, x + 1.0f, y + 1.0f, width - 2.0f, height - 2.0f);
    outlineEdges(outer, inner, renderer->m_r, renderer->m_g, renderer->m_b, renderer->m_a);
}

void fried_renderer_draw_batch(int rendererId, const int *ints, const float *floats, int count)
{
    if (isSoftware(rendererId))
    {
        fried_draw_batch_with_calls(rendererId, ints, floats, count);
        return;
    }
    Renderer *renderer = s_renderers.get(rendererId);
    if (renderer && count > 0)
    {
        drawBatchRecords(*renderer, ints, floats, count);
    }
}

void fried_renderer_fill_triangles(int rendererId, const fried_real *points, const int *argbColors, int triangleCount)
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
        const fried_real *corners = points + index * 6;
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

// The bottom screen's software renderer draws triangles only.
bool fried_renderer_draws_meshes(int rendererId)
{
    return !isSoftware(rendererId) && s_renderers.get(rendererId) != nullptr;
}

// Rotation goes about z, then x, then y, as MeshPass turns a mesh. The engine
// leaves out the triangles that face away from the camera. All of it is in
// integers once the view is set, as it is the same for every mesh in a band.
void fried_renderer_draw_mesh(int rendererId, int meshId, const fried_real *placement, bool hasCamera, double zoom, double cameraX, double cameraY)
{
    Renderer *renderer = isSoftware(rendererId) ? nullptr : s_renderers.get(rendererId);
    FriedNdsMesh *mesh = fried_mesh_get_nds(meshId);
    if (!renderer || !mesh || !placement)
    {
        return;
    }
    enterMeshes(placement, hasCamera, zoom, cameraX, cameraY, renderer->m_layout);

    int64_t x = fried_to_fixed(placement[FRIED_MESH_X], 12) - s_meshCameraX;
    int64_t y = fried_to_fixed(placement[FRIED_MESH_Y], 12) - s_meshCameraY;
    int64_t z = fried_to_fixed(placement[FRIED_MESH_Z], 12) - s_meshCameraZ;
    if (std::abs(x) > s_farthestMesh || std::abs(y) > s_farthestMesh || std::abs(z) > s_farthestMesh)
    {
        return;
    }
    int64_t scaleX = std::clamp<int64_t>(fried_to_fixed(placement[FRIED_MESH_SCALE_X], 12 + mesh->m_unitShift), INT32_MIN, INT32_MAX);
    int64_t scaleY = std::clamp<int64_t>(fried_to_fixed(placement[FRIED_MESH_SCALE_Y], 12 + mesh->m_unitShift), INT32_MIN, INT32_MAX);
    int64_t scaleZ = std::clamp<int64_t>(fried_to_fixed(placement[FRIED_MESH_SCALE_Z], 12 + mesh->m_unitShift), INT32_MIN, INT32_MAX);

    if (mesh->m_ambient != s_meshAmbient)
    {
        fried_mesh_set_ambient_nds(mesh, s_meshAmbient);
    }

    glPushMatrix();
    glTranslatef32((int)x, (int)y, (int)z);
    glRotateYi(toAngle(placement[FRIED_MESH_ROTATION_Y]));
    glRotateXi(toAngle(placement[FRIED_MESH_ROTATION_X]));
    glRotateZi(toAngle(placement[FRIED_MESH_ROTATION_Z]));
    glScalef32((int)scaleX, (int)scaleY, (int)scaleZ);

    for (int index = 0; index < mesh->m_listCount; ++index)
    {
        const FriedNdsList &list = mesh->m_lists[index];
        if (startPolygons(list.m_cornerCount == 4 ? GL_QUADS : GL_TRIANGLES, list.m_alpha, nullptr, s_meshCulling | POLY_FORMAT_LIGHT0))
        {
            sendCommands(list.m_words, list.m_wordCount);
            glEnd();
        }
    }
    glPopMatrix(1);
}
