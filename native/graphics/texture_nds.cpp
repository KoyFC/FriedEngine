#include "graphics/texture.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/renderer.h"

#include <fcntl.h>
#include <unistd.h>
#include <nds.h>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <new>
#include <vector>

// Textures live in VRAM banks A and B, which the 3D engine reads them from,
// at sizes that are powers of two from 8 to 1024 texels a side. An image is
// put in the top left corner of the smallest one that holds it, and one
// larger than 1024 is halved until it fits.

// PNGs are decoded with stb_image, as on the calculator.
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#define STBI_NO_STDIO
#define STBI_NO_LINEAR
#define STBI_NO_HDR
#include "third_party/stb_image.h"

namespace
{
    constexpr int s_minSide = 8;
    constexpr int s_maxSide = 1024;

    // A blank texture keeps a copy of its texels in main RAM, since VRAM takes
    // no byte writes and the 3D engine reads it whenever the screen is drawn.
    struct Texture
    {
        FriedNdsTexture m_public;
        std::vector<uint8_t> m_texels;
        int m_dirtyTop;
        int m_dirtyBottom;
    };

    HandlePool<Texture> s_textures;

    // Coverage in the top five bits, over a palette that is white throughout.
    const uint16_t s_whitePalette[8] = {0x7fff, 0x7fff, 0x7fff, 0x7fff, 0x7fff, 0x7fff, 0x7fff, 0x7fff};

    int sideFor(int size)
    {
        int side = s_minSide;
        while (side < size)
        {
            side *= 2;
        }
        return side;
    }

    int sizeEnumOf(int side)
    {
        int size = TEXTURE_SIZE_8;
        while ((s_minSide << size) < side)
        {
            ++size;
        }
        return size;
    }

    void destroy(Texture *texture)
    {
        if (!texture)
        {
            return;
        }
        glDeleteTextures(1, &texture->m_public.m_name);
        delete texture;
    }

    // glTexImage2D() copies from main RAM by DMA, which does not see the cache.
    Texture *upload(GL_TEXTURE_TYPE_ENUM format, int width, int height, int side, int sideHeight, const void *texels, int bytes)
    {
        Texture *texture = new (std::nothrow) Texture{{0, width, height, 1, side, sideHeight, format == GL_RGB8_A5}, {}, 0, 0};
        if (!texture)
        {
            return nullptr;
        }
        DC_FlushRange(texels, bytes);
        if (!glGenTextures(1, &texture->m_public.m_name))
        {
            delete texture;
            return nullptr;
        }
        glBindTexture(0, texture->m_public.m_name);
        if (!glTexImage2D(0, 0, format, sizeEnumOf(side), sizeEnumOf(sideHeight), 0, TEXGEN_OFF, texels))
        {
            destroy(texture);
            return nullptr;
        }
        return texture;
    }

    // One read for the whole file, as the other platforms without SDL do.
    unsigned char *readFile(const char *path, int &size)
    {
        int fd = open(path, O_RDONLY);
        if (fd < 0)
        {
            fried_set_last_error("No such file");
            return nullptr;
        }

        off_t end = lseek(fd, 0, SEEK_END);
        unsigned char *contents = end > 0 ? new (std::nothrow) unsigned char[end] : nullptr;
        bool read = contents && lseek(fd, 0, SEEK_SET) == 0 && ::read(fd, contents, end) == end;
        close(fd);

        if (!read)
        {
            delete[] contents;
            fried_set_last_error(end > 0 && !contents ? "Not enough memory to read the file" : "Failed to read the file");
            return nullptr;
        }
        size = (int)end;
        return contents;
    }

    // The texel format has one bit of alpha, so a pixel is drawn where the
    // image is at least half opaque and left out elsewhere.
    uint16_t toTexel(const unsigned char *pixel)
    {
        if (pixel[3] < 128)
        {
            return 0;
        }
        return (uint16_t)(0x8000 | ((pixel[2] >> 3) << 10) | ((pixel[1] >> 3) << 5) | (pixel[0] >> 3));
    }

    // The 3D engine reads textures while the screen is drawn, so they are only
    // written during the vertical blank, with banks A and B lent to the CPU.
    void writeDirtyRows(Texture &texture)
    {
        const FriedNdsTexture &info = texture.m_public;
        uint8_t *vram = (uint8_t *)glGetTexturePointer(info.m_name);
        if (!vram)
        {
            return;
        }
        int offset = texture.m_dirtyTop * info.m_textureWidth;
        int bytes = (texture.m_dirtyBottom - texture.m_dirtyTop) * info.m_textureWidth;
        const uint32_t *source = (const uint32_t *)(texture.m_texels.data() + offset);
        volatile uint32_t *destination = (volatile uint32_t *)(vram + offset);
        for (int index = 0; index < bytes / 4; ++index)
        {
            destination[index] = source[index];
        }
        texture.m_dirtyTop = 0;
        texture.m_dirtyBottom = 0;
    }
}

const FriedNdsTexture *fried_texture_get_nds(int textureId)
{
    Texture *texture = s_textures.get(textureId);
    return texture ? &texture->m_public : nullptr;
}

void fried_texture_write_pending()
{
    bool pending = false;
    for (int id = 0; id < s_textures.capacity() && !pending; ++id)
    {
        Texture *texture = s_textures.get(id);
        pending = texture && texture->m_dirtyBottom > texture->m_dirtyTop;
    }
    if (!pending)
    {
        return;
    }

    swiWaitForVBlank();
    uint8_t bankA = VRAM_A_CR;
    uint8_t bankB = VRAM_B_CR;
    vramSetBankA(VRAM_A_LCD);
    vramSetBankB(VRAM_B_LCD);
    for (int id = 0; id < s_textures.capacity(); ++id)
    {
        Texture *texture = s_textures.get(id);
        if (texture && texture->m_dirtyBottom > texture->m_dirtyTop)
        {
            writeDirtyRows(*texture);
        }
    }
    VRAM_A_CR = bankA;
    VRAM_B_CR = bankB;
}

int fried_texture_create_blank(int rendererId, int width, int height)
{
    if (fried_renderer_get_width(rendererId) <= 0)
    {
        fried_set_last_error("No such renderer");
        return -1;
    }

    int side = sideFor(width);
    int sideHeight = sideFor(height);
    if (side > s_maxSide || sideHeight > s_maxSide)
    {
        fried_set_last_error("A blank texture is at most 1024 texels a side");
        return -1;
    }
    std::vector<uint8_t> texels((size_t)side * sideHeight);

    Texture *texture = upload(GL_RGB8_A5, width, height, side, sideHeight, texels.data(), (int)texels.size());
    if (!texture)
    {
        fried_set_last_error("Not enough VRAM for a blank texture");
        return -1;
    }
    glColorTableEXT(0, 0, 8, 0, 0, s_whitePalette);
    texture->m_texels = std::move(texels);
    return s_textures.store(texture);
}

bool fried_texture_write_alpha(int textureId, int x, int y, const uint8_t *alpha, int width, int height)
{
    Texture *texture = s_textures.get(textureId);
    if (!texture || texture->m_texels.empty() || x < 0 || y < 0 || x + width > texture->m_public.m_width || y + height > texture->m_public.m_height)
    {
        return false;
    }

    int stride = texture->m_public.m_textureWidth;
    for (int row = 0; row < height; ++row)
    {
        uint8_t *texel = texture->m_texels.data() + (y + row) * stride + x;
        const uint8_t *coverage = alpha + row * width;
        for (int column = 0; column < width; ++column)
        {
            texel[column] = coverage[column] & 0xf8;
        }
    }

    if (texture->m_dirtyBottom <= texture->m_dirtyTop)
    {
        texture->m_dirtyTop = y;
        texture->m_dirtyBottom = y + height;
    }
    else
    {
        texture->m_dirtyTop = std::min(texture->m_dirtyTop, y);
        texture->m_dirtyBottom = std::max(texture->m_dirtyBottom, y + height);
    }
    return true;
}

int fried_texture_load(int rendererId, const char *path)
{
    if (fried_renderer_get_width(rendererId) <= 0 || !path)
    {
        fried_set_last_error("No such renderer, or no path given");
        return -1;
    }

    int size = 0;
    unsigned char *contents = readFile(path, size);
    if (!contents)
    {
        return -1;
    }

    int width = 0, height = 0, channels = 0;
    unsigned char *rgba = stbi_load_from_memory(contents, size, &width, &height, &channels, 4);
    delete[] contents;
    if (!rgba)
    {
        fried_set_last_error(stbi_failure_reason());
        return -1;
    }

    int downscale = 1;
    while (width / downscale > s_maxSide || height / downscale > s_maxSide)
    {
        downscale *= 2;
    }
    int storedWidth = std::max(1, width / downscale);
    int storedHeight = std::max(1, height / downscale);
    int side = sideFor(storedWidth);
    int sideHeight = sideFor(storedHeight);

    std::vector<uint16_t> texels((size_t)side * sideHeight);
    for (int y = 0; y < storedHeight; ++y)
    {
        for (int x = 0; x < storedWidth; ++x)
        {
            texels[(size_t)y * side + x] = toTexel(rgba + ((size_t)y * downscale * width + (size_t)x * downscale) * 4);
        }
    }
    stbi_image_free(rgba);

    Texture *texture = upload(GL_RGBA, width, height, side, sideHeight, texels.data(), (int)(texels.size() * sizeof(uint16_t)));
    if (!texture)
    {
        char message[96];
        std::snprintf(message, sizeof(message), "Not enough VRAM for a %dx%d image", width, height);
        fried_set_last_error(message);
        return -1;
    }
    texture->m_public.m_downscale = downscale;
    return s_textures.store(texture);
}

void fried_texture_destroy(int textureId)
{
    destroy(s_textures.release(textureId));
}

int fried_texture_get_width(int textureId)
{
    const FriedNdsTexture *texture = fried_texture_get_nds(textureId);
    return texture ? texture->m_width : 0;
}

int fried_texture_get_height(int textureId)
{
    const FriedNdsTexture *texture = fried_texture_get_nds(textureId);
    return texture ? texture->m_height : 0;
}

int fried_texture_get_downscale(int textureId)
{
    const FriedNdsTexture *texture = fried_texture_get_nds(textureId);
    return texture ? texture->m_downscale : 0;
}
