#include "graphics/renderer.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/display.h"
#include "graphics/font.h"
#include "graphics/texture.h"
#include "platform/window.h"

#include <SDL.h>
#include <citro2d.h>

#include <algorithm>
#include <cstring>

namespace
{
    struct CitroRenderer
    {
        C3D_RenderTarget *target;
        gfxScreen_t screen;
        FriedDisplayLayout layout;
        u32 drawColor;
    };

    HandlePool<CitroRenderer> s_renderers;

    // Every screen draws within one GPU frame, which the first present ends.
    bool s_isFrameOpen = false;
    CitroRenderer *s_sceneRenderer = nullptr;

    constexpr float s_depth = 0.0f;
    constexpr float s_degreesToRadians = 3.14159265358979f / 180.0f;
    constexpr int s_flipHorizontal = 1;
    constexpr int s_flipVertical = 2;

    bool startCitro()
    {
        if (!C3D_Init(C3D_DEFAULT_CMDBUF_SIZE))
        {
            return false;
        }
        if (!C2D_Init(C2D_DEFAULT_MAX_OBJECTS))
        {
            C3D_Fini();
            return false;
        }
        C2D_Prepare();
        return true;
    }

    void stopCitro()
    {
        C2D_Fini();
        C3D_Fini();
    }

    // The screens are mounted rotated, so GSP names their width a height.
    int screenWidth(gfxScreen_t screen)
    {
        return screen == GFX_TOP ? GSP_SCREEN_HEIGHT_TOP : GSP_SCREEN_HEIGHT_BOTTOM;
    }

    constexpr int s_screenHeight = GSP_SCREEN_WIDTH;

    // The project's display only applies to the top screen.
    FriedDisplayLayout layoutOfScreen(gfxScreen_t screen)
    {
        int width = screenWidth(screen);
        if (screen == GFX_TOP)
        {
            return fried_display_layout(width, s_screenHeight);
        }
        return {width, s_screenHeight, 0, 0, width, s_screenHeight, 1.0f, 1.0f};
    }

    gfxScreen_t screenOfWindow(SDL_Window *window)
    {
        return SDL_GetWindowDisplayIndex(window) == 0 ? GFX_TOP : GFX_BOTTOM;
    }

    gfxScreen_t otherScreen(gfxScreen_t screen)
    {
        return screen == GFX_TOP ? GFX_BOTTOM : GFX_TOP;
    }

    // Both of its buffers, so a screen nothing draws on stops showing whatever
    // the launcher or a closed renderer left there.
    void blankScreen(gfxScreen_t screen)
    {
        u32 bytesPerPixel = gspGetBytesPerPixel(gfxGetScreenFormat(screen));
        for (int buffer = 0; buffer < 2; ++buffer)
        {
            u16 width = 0;
            u16 height = 0;
            u8 *framebuffer = gfxGetFramebuffer(screen, GFX_LEFT, &width, &height);
            u32 size = width * height * bytesPerPixel;
            std::memset(framebuffer, 0, size);
            GSPGPU_FlushDataCache(framebuffer, size);
            gfxScreenSwapBuffers(screen, false);
        }
    }

    void beginScene(CitroRenderer *renderer)
    {
        if (!s_isFrameOpen)
        {
            C3D_FrameBegin(C3D_FRAME_SYNCDRAW);
            s_isFrameOpen = true;
            s_sceneRenderer = nullptr;
        }
        if (s_sceneRenderer != renderer)
        {
            C2D_SceneBegin(renderer->target);
            const FriedDisplayLayout &layout = renderer->layout;
            C2D_ViewReset();
            C2D_ViewTranslate(layout.m_viewportX, layout.m_viewportY);
            C2D_ViewScale(layout.m_scaleX, layout.m_scaleY);
            s_sceneRenderer = renderer;
        }
    }

    CitroRenderer *sceneRenderer(int rendererId)
    {
        CitroRenderer *renderer = s_renderers.get(rendererId);
        if (renderer)
        {
            beginScene(renderer);
        }
        return renderer;
    }

    // The region is in the source's pixels, which a downscaled texture holds fewer of.
    Tex3DS_SubTexture regionOf(const C2D_Image &image, int srcX, int srcY, int srcWidth, int srcHeight)
    {
        const Tex3DS_SubTexture *whole = image.subtex;
        float uPerPixel = (whole->right - whole->left) / whole->width;
        float vPerPixel = (whole->top - whole->bottom) / whole->height;
        return {
            (u16)srcWidth,
            (u16)srcHeight,
            whole->left + srcX * uPerPixel,
            whole->top - srcY * vPerPixel,
            whole->left + (srcX + srcWidth) * uPerPixel,
            whole->top - (srcY + srcHeight) * vPerPixel,
        };
    }

    FriedRect snapped(const CitroRenderer *renderer, float x, float y, float width, float height)
    {
        return fried_display_snap(x, y, width, height, renderer->layout.m_scaleX, renderer->layout.m_scaleY);
    }

    void fillRect(float x, float y, float width, float height, u32 color)
    {
        C2D_DrawRectSolid(x, y, s_depth, width, height, color);
    }

    // Painted over the frame rather than clipped to, so whatever was drawn past
    // the viewport is hidden too.
    void drawLetterboxBars(CitroRenderer *renderer)
    {
        const FriedDisplayLayout &layout = renderer->layout;
        int outputWidth = screenWidth(renderer->screen);
        int outputHeight = s_screenHeight;
        int viewportRight = layout.m_viewportX + layout.m_viewportWidth;
        int viewportBottom = layout.m_viewportY + layout.m_viewportHeight;
        if (layout.m_viewportX == 0 && layout.m_viewportY == 0 && viewportRight == outputWidth && viewportBottom == outputHeight)
        {
            return;
        }

        beginScene(renderer);
        C2D_ViewReset();
        u32 black = C2D_Color32(0, 0, 0, 255);
        fillRect(0, 0, outputWidth, layout.m_viewportY, black);
        fillRect(0, viewportBottom, outputWidth, outputHeight - viewportBottom, black);
        fillRect(0, layout.m_viewportY, layout.m_viewportX, layout.m_viewportHeight, black);
        fillRect(viewportRight, layout.m_viewportY, outputWidth - viewportRight, layout.m_viewportHeight, black);
        s_sceneRenderer = nullptr;
    }
}

int fried_renderer_create(int windowId, bool vsync)
{
    (void)vsync;
    SDL_Window *window = fried_window_get_sdl(windowId);
    if (!window)
    {
        fried_set_last_error("No such window");
        return -1;
    }

    bool isFirstRenderer = s_renderers.count() == 0;
    if (isFirstRenderer && !startCitro())
    {
        fried_set_last_error("Failed to initialize citro2d");
        return -1;
    }

    gfxScreen_t screen = screenOfWindow(window);
    if (isFirstRenderer)
    {
        blankScreen(otherScreen(screen));
    }
    // citro2d's screen targets output BGR8, and SDL left the screens at RGBA8.
    gfxSetScreenFormat(screen, GSP_BGR8_OES);

    C3D_RenderTarget *target = C2D_CreateScreenTarget(screen, GFX_LEFT);
    if (!target)
    {
        if (isFirstRenderer)
        {
            stopCitro();
        }
        fried_set_last_error("Failed to create a citro2d screen target");
        return -1;
    }

    CitroRenderer *renderer = new CitroRenderer();
    renderer->target = target;
    renderer->screen = screen;
    renderer->layout = layoutOfScreen(screen);
    renderer->drawColor = C2D_Color32(0, 0, 0, 255);
    return s_renderers.store(renderer);
}

void fried_renderer_destroy(int rendererId)
{
    CitroRenderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    fried_font_release_renderer(rendererId);
    s_renderers.release(rendererId);
    if (s_sceneRenderer == renderer)
    {
        s_sceneRenderer = nullptr;
    }
    C3D_RenderTargetDelete(renderer->target);
    blankScreen(renderer->screen);
    delete renderer;

    if (s_renderers.count() == 0)
    {
        stopCitro();
    }
}

// C3D_FrameBegin() waits for the VBlank whether or not the game asked for it.
bool fried_renderer_has_vsync(int rendererId)
{
    return s_renderers.get(rendererId) != nullptr;
}

int fried_renderer_get_width(int rendererId)
{
    CitroRenderer *renderer = s_renderers.get(rendererId);
    return renderer ? renderer->layout.m_width : 0;
}

int fried_renderer_get_height(int rendererId)
{
    CitroRenderer *renderer = s_renderers.get(rendererId);
    return renderer ? renderer->layout.m_height : 0;
}

void fried_renderer_set_draw_color(int rendererId, int r, int g, int b, int a)
{
    CitroRenderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    renderer->drawColor = C2D_Color32((u8)r, (u8)g, (u8)b, (u8)a);
}

void fried_renderer_clear(int rendererId)
{
    CitroRenderer *renderer = sceneRenderer(rendererId);
    if (!renderer)
    {
        return;
    }
    C2D_TargetClear(renderer->target, renderer->drawColor);
}

void fried_renderer_present(int rendererId)
{
    if (!s_renderers.get(rendererId) || !s_isFrameOpen)
    {
        return;
    }
    for (int id = 0; id < s_renderers.capacity(); ++id)
    {
        CitroRenderer *renderer = s_renderers.get(id);
        if (renderer)
        {
            drawLetterboxBars(renderer);
        }
    }
    C3D_FrameEnd(0);
    s_isFrameOpen = false;
    s_sceneRenderer = nullptr;
}

void fried_renderer_draw_texture(int rendererId, int textureId, float x, float y, float width, float height)
{
    const C2D_Image *image = fried_texture_get_citro(textureId);
    CitroRenderer *renderer = image ? sceneRenderer(rendererId) : nullptr;
    if (!renderer)
    {
        return;
    }

    FriedRect destination = snapped(renderer, x, y, width, height);
    C2D_DrawParams params = {};
    params.pos = {destination.m_x, destination.m_y, destination.m_width, destination.m_height};
    params.depth = s_depth;
    C2D_DrawImage(*image, &params, nullptr);
}

void fried_renderer_draw_texture_ex(int rendererId, int textureId, int srcX, int srcY, int srcWidth, int srcHeight, float x, float y, float width, float height, double angle, int flipMode)
{
    const C2D_Image *image = fried_texture_get_citro(textureId);
    CitroRenderer *renderer = image ? sceneRenderer(rendererId) : nullptr;
    if (!renderer)
    {
        return;
    }

    Tex3DS_SubTexture region = regionOf(*image, srcX, srcY, srcWidth, srcHeight);
    FriedRect destination = snapped(renderer, x, y, width, height);

    // Rotated about the centre of the destination, as SDL_RenderCopyEx() does.
    // A negative size is how citro2d flips an image.
    float halfWidth = destination.m_width / 2.0f;
    float halfHeight = destination.m_height / 2.0f;
    C2D_DrawParams params = {};
    params.pos = {
        destination.m_x + halfWidth,
        destination.m_y + halfHeight,
        (flipMode & s_flipHorizontal) ? -destination.m_width : destination.m_width,
        (flipMode & s_flipVertical) ? -destination.m_height : destination.m_height,
    };
    params.center = {halfWidth, halfHeight};
    params.depth = s_depth;
    params.angle = (float)angle * s_degreesToRadians;
    C2D_DrawImage({image->tex, &region}, &params, nullptr);
}

void fried_renderer_draw_tinted(int rendererId, int textureId, const FriedQuad *quads, int count, int r, int g, int b, int a)
{
    const C2D_Image *image = fried_texture_get_citro(textureId);
    CitroRenderer *renderer = image ? sceneRenderer(rendererId) : nullptr;
    if (!renderer)
    {
        return;
    }

    // At full blend the solid tint replaces the colour and multiplies the alpha.
    C2D_ImageTint tint;
    C2D_PlainImageTint(&tint, C2D_Color32((u8)r, (u8)g, (u8)b, (u8)a), 1.0f);
    for (int index = 0; index < count; ++index)
    {
        const FriedQuad &quad = quads[index];
        Tex3DS_SubTexture region = regionOf(*image, quad.m_srcX, quad.m_srcY, quad.m_srcWidth, quad.m_srcHeight);
        FriedRect destination = snapped(renderer, quad.m_x, quad.m_y, quad.m_width, quad.m_height);
        C2D_DrawParams params = {};
        params.pos = {quad.m_pivotX, quad.m_pivotY, destination.m_width, destination.m_height};
        params.center = {quad.m_pivotX - destination.m_x, quad.m_pivotY - destination.m_y};
        params.depth = s_depth;
        params.angle = quad.m_angle * s_degreesToRadians;
        C2D_DrawImage({image->tex, &region}, &params, &tint);
    }
}

void fried_renderer_fill_rect(int rendererId, float x, float y, float width, float height)
{
    CitroRenderer *renderer = sceneRenderer(rendererId);
    if (!renderer)
    {
        return;
    }
    FriedRect rect = snapped(renderer, x, y, width, height);
    fillRect(rect.m_x, rect.m_y, rect.m_width, rect.m_height, renderer->drawColor);
}

// One pixel wide and inside the rectangle, as SDL_RenderDrawRect() draws it.
void fried_renderer_draw_rect(int rendererId, float x, float y, float width, float height)
{
    CitroRenderer *renderer = sceneRenderer(rendererId);
    if (!renderer || width <= 0 || height <= 0)
    {
        return;
    }
    FriedRect rect = snapped(renderer, x, y, width, height);
    u32 color = renderer->drawColor;
    fillRect(rect.m_x, rect.m_y, rect.m_width, 1, color);
    fillRect(rect.m_x, rect.m_y + rect.m_height - 1, rect.m_width, 1, color);
    fillRect(rect.m_x, rect.m_y + 1, 1, rect.m_height - 2, color);
    fillRect(rect.m_x + rect.m_width - 1, rect.m_y + 1, 1, rect.m_height - 2, color);
}

void fried_renderer_window_to_logical(int windowId, int x, int y, int &logicalX, int &logicalY)
{
    (void)windowId;
    logicalX = x;
    logicalY = y;
}

void fried_renderer_touch_to_logical(int windowId, float x, float y, int &logicalX, int &logicalY)
{
    SDL_Window *window = fried_window_get_sdl(windowId);
    if (!window)
    {
        logicalX = 0;
        logicalY = 0;
        return;
    }

    FriedDisplayLayout layout = layoutOfScreen(screenOfWindow(window));
    float outputX = x * fried_window_get_width(windowId);
    float outputY = y * fried_window_get_height(windowId);
    int pixelX = (int)((outputX - layout.m_viewportX) / layout.m_scaleX);
    int pixelY = (int)((outputY - layout.m_viewportY) / layout.m_scaleY);
    logicalX = std::clamp(pixelX, 0, std::max(0, layout.m_width - 1));
    logicalY = std::clamp(pixelY, 0, std::max(0, layout.m_height - 1));
}

float fried_renderer_get_pixel_scale(int rendererId)
{
    CitroRenderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return 1.0f;
    }
    return std::min(renderer->layout.m_scaleX, renderer->layout.m_scaleY);
}
