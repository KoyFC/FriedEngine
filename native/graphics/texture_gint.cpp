#include "graphics/texture.h"

#include "handle_pool.h"
#include "last_error.h"
#include "graphics/renderer.h"

#include <fcntl.h>
#include <unistd.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <new>

// gint has no image decoder, so PNGs are decoded with stb_image, the same
// decoder SDL2_image uses on the other platforms, and only its PNG one.
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#define STBI_NO_STDIO
#define STBI_NO_LINEAR
#define STBI_NO_HDR
#include "third_party/stb_image.h"

namespace
{
    HandlePool<FriedGintTexture> s_textures;

    void destroy(FriedGintTexture *texture)
    {
        if (!texture)
        {
            return;
        }
        delete[] texture->m_pixels;
        delete[] texture->m_alpha;
        delete texture;
    }

    // One read for the whole file: each call into the filesystem is a world
    // switch to the OS and back.
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

    FriedGintTexture *convert(const unsigned char *rgba, int width, int height)
    {
        int count = width * height;
        bool translucent = false;
        for (int index = 0; index < count && !translucent; ++index)
        {
            translucent = rgba[index * 4 + 3] != 255;
        }

        FriedGintTexture *texture = new (std::nothrow) FriedGintTexture{width, height, nullptr, nullptr};
        if (texture)
        {
            texture->m_pixels = new (std::nothrow) uint16_t[count];
            texture->m_alpha = translucent ? new (std::nothrow) uint8_t[count] : nullptr;
        }
        if (!texture || !texture->m_pixels || (translucent && !texture->m_alpha))
        {
            destroy(texture);
            return nullptr;
        }

        for (int index = 0; index < count; ++index)
        {
            const unsigned char *pixel = rgba + index * 4;
            texture->m_pixels[index] = (uint16_t)(((pixel[0] & 0xf8) << 8) | ((pixel[1] & 0xfc) << 3) | (pixel[2] >> 3));
            if (translucent)
            {
                texture->m_alpha[index] = pixel[3];
            }
        }
        return texture;
    }
}

const FriedGintTexture *fried_texture_get_gint(int textureId)
{
    return s_textures.get(textureId);
}

int fried_texture_create_blank(int rendererId, int width, int height)
{
    if (fried_renderer_get_width(rendererId) <= 0)
    {
        fried_set_last_error("No such renderer");
        return -1;
    }

    FriedGintTexture *texture = new (std::nothrow) FriedGintTexture{width, height, nullptr, nullptr};
    if (texture)
    {
        texture->m_alpha = new (std::nothrow) uint8_t[width * height]();
    }
    if (!texture || !texture->m_alpha)
    {
        destroy(texture);
        fried_set_last_error("Not enough memory for a blank texture");
        return -1;
    }
    return s_textures.store(texture);
}

bool fried_texture_write_alpha(int textureId, int x, int y, const uint8_t *alpha, int width, int height)
{
    FriedGintTexture *texture = s_textures.get(textureId);
    if (!texture || !texture->m_alpha || x < 0 || y < 0 || x + width > texture->m_width || y + height > texture->m_height)
    {
        return false;
    }
    for (int row = 0; row < height; ++row)
    {
        std::memcpy(texture->m_alpha + (y + row) * texture->m_width + x, alpha + row * width, width);
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

    FriedGintTexture *texture = convert(rgba, width, height);
    stbi_image_free(rgba);
    if (!texture)
    {
        char message[96];
        std::snprintf(message, sizeof(message), "Not enough memory for a %dx%d image", width, height);
        fried_set_last_error(message);
        return -1;
    }

    return s_textures.store(texture);
}

void fried_texture_destroy(int textureId)
{
    destroy(s_textures.release(textureId));
}

int fried_texture_get_width(int textureId)
{
    const FriedGintTexture *texture = s_textures.get(textureId);
    return texture ? texture->m_width : 0;
}

int fried_texture_get_height(int textureId)
{
    const FriedGintTexture *texture = s_textures.get(textureId);
    return texture ? texture->m_height : 0;
}

int fried_texture_get_downscale(int textureId)
{
    return s_textures.get(textureId) ? 1 : 0;
}
