#include "graphics/renderer.h"

#include "handle_pool.h"
#include "graphics/texture.h"
#include "platform/window.h"

#include <SDL.h>

namespace
{
    HandlePool<SDL_Renderer> s_renderers;
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
        return -1;
    }

    SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
    return s_renderers.store(renderer);
}

void fried_renderer_destroy(int rendererId)
{
    SDL_Renderer *renderer = s_renderers.release(rendererId);
    if (!renderer)
    {
        return;
    }
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
    int width = 0, height = 0;
    SDL_GetRendererOutputSize(renderer, &width, &height);
    return width;
}

int fried_renderer_get_height(int rendererId)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return 0;
    }
    int width = 0, height = 0;
    SDL_GetRendererOutputSize(renderer, &width, &height);
    return height;
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
    SDL_RenderClear(renderer);
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
