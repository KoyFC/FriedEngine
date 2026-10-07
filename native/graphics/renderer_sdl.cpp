#include "graphics/renderer.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/display.h"
#include "graphics/font.h"
#include "graphics/texture.h"
#include "platform/window.h"

#include <SDL.h>

#include <algorithm>
#include <cmath>

namespace
{
    HandlePool<SDL_Renderer> s_renderers;

    FriedDisplayLayout layoutOf(SDL_Renderer *renderer)
    {
        int width = 0, height = 0;
        SDL_GetRendererOutputSize(renderer, &width, &height);
        return fried_display_layout(width, height);
    }

    // Runs every frame because SDL resets the viewport on any window resize.
    // SDL multiplies a new viewport by the current scale, hence the reset to 1.
    FriedDisplayLayout applyLayout(SDL_Renderer *renderer)
    {
        FriedDisplayLayout layout = layoutOf(renderer);
        SDL_Rect viewport = {layout.m_viewportX, layout.m_viewportY, layout.m_viewportWidth, layout.m_viewportHeight};
        SDL_RenderSetScale(renderer, 1.0f, 1.0f);
        SDL_RenderSetViewport(renderer, &viewport);
        SDL_RenderSetScale(renderer, layout.m_scaleX, layout.m_scaleY);
        return layout;
    }

    bool isLetterboxed(SDL_Renderer *renderer, const FriedDisplayLayout &layout)
    {
        int width = 0, height = 0;
        SDL_GetRendererOutputSize(renderer, &width, &height);
        return layout.m_viewportWidth < width || layout.m_viewportHeight < height;
    }

    SDL_Renderer *rendererOfWindow(int windowId)
    {
        SDL_Window *window = fried_window_get_sdl(windowId);
        return window ? SDL_GetRenderer(window) : nullptr;
    }

    int clampToPixelInside(int value, int size)
    {
        return std::clamp(value, 0, std::max(0, size - 1));
    }
}

SDL_Renderer *fried_renderer_get_sdl(int rendererId)
{
    return s_renderers.get(rendererId);
}

int fried_renderer_create(int windowId, bool vsync)
{
    SDL_Window *window = fried_window_get_sdl(windowId);
    if (!window)
    {
        fried_set_last_error("No such window");
        return -1;
    }

    Uint32 flags = SDL_RENDERER_ACCELERATED;
    if (vsync)
    {
        flags |= SDL_RENDERER_PRESENTVSYNC;
    }

    SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, flags);
    if (!renderer && vsync)
    {
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    }
    if (!renderer)
    {
        fried_capture_sdl_error();
        return -1;
    }

    SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
    applyLayout(renderer);
    return s_renderers.store(renderer);
}

void fried_renderer_destroy(int rendererId)
{
    SDL_Renderer *renderer = s_renderers.get(rendererId);
    if (!renderer)
    {
        return;
    }
    fried_font_release_renderer(rendererId);
    s_renderers.release(rendererId);
    SDL_DestroyRenderer(renderer);
}

bool fried_renderer_has_vsync(int rendererId)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return false;
    }

    SDL_RendererInfo info;
    if (SDL_GetRendererInfo(renderer, &info) != 0)
    {
        return false;
    }
    return (info.flags & SDL_RENDERER_PRESENTVSYNC) != 0;
}

int fried_renderer_get_width(int rendererId)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return 0;
    }
    return layoutOf(renderer).m_width;
}

int fried_renderer_get_height(int rendererId)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return 0;
    }
    return layoutOf(renderer).m_height;
}

void fried_renderer_set_draw_color(int rendererId, int r, int g, int b, int a)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return;
    }
    SDL_SetRenderDrawColor(renderer, (Uint8)r, (Uint8)g, (Uint8)b, (Uint8)a);
}

void fried_renderer_clear(int rendererId)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return;
    }

    FriedDisplayLayout layout = applyLayout(renderer);
    if (!isLetterboxed(renderer, layout))
    {
        SDL_RenderClear(renderer);
        return;
    }

    // SDL_RenderClear ignores the viewport, so it would paint the bars too.
    Uint8 r, g, b, a;
    SDL_GetRenderDrawColor(renderer, &r, &g, &b, &a);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    SDL_SetRenderDrawColor(renderer, r, g, b, a);
    SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_NONE);
    SDL_RenderFillRect(renderer, nullptr);
    SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
}

void fried_renderer_present(int rendererId)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return;
    }
    SDL_RenderPresent(renderer);
}

void fried_renderer_draw_texture(int rendererId, int textureId, int x, int y, int width, int height)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    SDL_Texture *texture = fried_texture_get_sdl(textureId);
    if (!renderer || !texture)
    {
        return;
    }

    SDL_Rect destination = {x, y, width, height};
    SDL_RenderCopy(renderer, texture, nullptr, &destination);
}

void fried_renderer_draw_texture_ex(int rendererId, int textureId, int srcX, int srcY, int srcWidth, int srcHeight, int x, int y, int width, int height, double angle, int flipMode)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    SDL_Texture *texture = fried_texture_get_sdl(textureId);
    if (!renderer || !texture)
    {
        return;
    }

    SDL_Rect source = {srcX, srcY, srcWidth, srcHeight};
    SDL_Rect destination = {x, y, width, height};
    SDL_RenderCopyEx(renderer, texture, &source, &destination, angle, nullptr, (SDL_RendererFlip)flipMode);
}

void fried_renderer_draw_tinted(int rendererId, int textureId, const FriedQuad *quads, int count, int r, int g, int b, int a)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    SDL_Texture *texture = fried_texture_get_sdl(textureId);
    if (!renderer || !texture)
    {
        return;
    }

    SDL_SetTextureColorMod(texture, (Uint8)r, (Uint8)g, (Uint8)b);
    SDL_SetTextureAlphaMod(texture, (Uint8)a);
    for (int index = 0; index < count; ++index)
    {
        const FriedQuad &quad = quads[index];
        SDL_Rect source = {quad.m_srcX, quad.m_srcY, quad.m_srcWidth, quad.m_srcHeight};
        SDL_FRect destination = {quad.m_x, quad.m_y, quad.m_width, quad.m_height};
        SDL_FPoint pivot = {quad.m_pivotX - quad.m_x, quad.m_pivotY - quad.m_y};
        SDL_RenderCopyExF(renderer, texture, &source, &destination, quad.m_angle, &pivot, SDL_FLIP_NONE);
    }
}

void fried_renderer_fill_rect(int rendererId, int x, int y, int width, int height)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return;
    }

    SDL_Rect rect = {x, y, width, height};
    SDL_RenderFillRect(renderer, &rect);
}

void fried_renderer_draw_rect(int rendererId, int x, int y, int width, int height)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return;
    }

    SDL_Rect rect = {x, y, width, height};
    SDL_RenderDrawRect(renderer, &rect);
}

void fried_renderer_window_to_logical(int windowId, int x, int y, int &logicalX, int &logicalY)
{
    SDL_Renderer *renderer = rendererOfWindow(windowId);
    if (!renderer)
    {
        logicalX = x;
        logicalY = y;
        return;
    }

    float convertedX, convertedY;
    SDL_RenderWindowToLogical(renderer, x, y, &convertedX, &convertedY);
    logicalX = (int)std::floor(convertedX);
    logicalY = (int)std::floor(convertedY);
}

// SDL's renderer has already made the touch relative to its viewport.
void fried_renderer_touch_to_logical(int windowId, float x, float y, int &logicalX, int &logicalY)
{
    SDL_Renderer *renderer = rendererOfWindow(windowId);
    int width = 0, height = 0;
    if (renderer)
    {
        FriedDisplayLayout layout = layoutOf(renderer);
        width = layout.m_width;
        height = layout.m_height;
    }
    else
    {
        SDL_GetWindowSize(fried_window_get_sdl(windowId), &width, &height);
    }
    logicalX = clampToPixelInside((int)(x * width), width);
    logicalY = clampToPixelInside((int)(y * height), height);
}

float fried_renderer_get_pixel_scale(int rendererId)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return 1.0f;
    }
    FriedDisplayLayout layout = layoutOf(renderer);
    return std::min(layout.m_scaleX, layout.m_scaleY);
}
