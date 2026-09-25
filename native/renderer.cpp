#include "renderer.h"

#include "texture.h"
#include "window.h"

#include <SDL.h>
#include <vector>

namespace
{
    std::vector<SDL_Renderer *> s_renderers;
    std::vector<int> s_freeRendererIds;

    int storeRenderer(SDL_Renderer *renderer)
    {
        if (!s_freeRendererIds.empty())
        {
            int rendererId = s_freeRendererIds.back();
            s_freeRendererIds.pop_back();
            s_renderers[rendererId] = renderer;
            return rendererId;
        }

        s_renderers.push_back(renderer);
        return (int)(s_renderers.size() - 1);
    }
}

SDL_Renderer *fried_renderer_get_sdl(int rendererId)
{
    if (rendererId < 0 || rendererId >= (int)s_renderers.size())
    {
        return nullptr;
    }
    return s_renderers[rendererId];
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
    return storeRenderer(renderer);
}

void fried_renderer_destroy(int rendererId)
{
    SDL_Renderer *renderer = fried_renderer_get_sdl(rendererId);
    if (!renderer)
    {
        return;
    }
    SDL_DestroyRenderer(renderer);
    s_renderers[rendererId] = nullptr;
    s_freeRendererIds.push_back(rendererId);
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
