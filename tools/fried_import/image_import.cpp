#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "image_import.h"

#include "stb_image.h"
#include "stb_image_write.h"

#include <algorithm>
#include <cstdint>
#include <cstring>

namespace fried_import
{
    namespace
    {
        uint32_t crc32Of(const unsigned char *data, size_t size)
        {
            static uint32_t table[256];
            static bool isBuilt = false;
            if (!isBuilt)
            {
                for (uint32_t index = 0; index < 256; ++index)
                {
                    uint32_t value = index;
                    for (int bit = 0; bit < 8; ++bit)
                    {
                        value = (value & 1) ? 0xedb88320u ^ (value >> 1) : value >> 1;
                    }
                    table[index] = value;
                }
                isBuilt = true;
            }
            uint32_t crc = 0xffffffffu;
            for (size_t index = 0; index < size; ++index)
            {
                crc = table[(crc ^ data[index]) & 0xff] ^ (crc >> 8);
            }
            return crc ^ 0xffffffffu;
        }

        void putBigEndian(std::vector<unsigned char> &bytes, uint32_t value)
        {
            for (int shift = 24; shift >= 0; shift -= 8)
            {
                bytes.push_back((unsigned char)(value >> shift));
            }
        }

        // Halves the image once, each new pixel being the average of up to four, weighted by their alpha so a transparent pixel's color does not leak into its neighbors.
        void halve(std::vector<unsigned char> &pixels, int *width, int *height)
        {
            int newWidth = (*width + 1) / 2;
            int newHeight = (*height + 1) / 2;
            std::vector<unsigned char> result((size_t)newWidth * newHeight * 4);
            for (int y = 0; y < newHeight; ++y)
            {
                for (int x = 0; x < newWidth; ++x)
                {
                    unsigned sum[3] = {0, 0, 0};
                    unsigned alphaSum = 0;
                    unsigned count = 0;
                    for (int dy = 0; dy < 2; ++dy)
                    {
                        for (int dx = 0; dx < 2; ++dx)
                        {
                            int sx = x * 2 + dx;
                            int sy = y * 2 + dy;
                            if (sx >= *width || sy >= *height)
                            {
                                continue;
                            }
                            const unsigned char *pixel = &pixels[((size_t)sy * *width + sx) * 4];
                            for (int channel = 0; channel < 3; ++channel)
                            {
                                sum[channel] += pixel[channel] * pixel[3];
                            }
                            alphaSum += pixel[3];
                            ++count;
                        }
                    }
                    unsigned char *target = &result[((size_t)y * newWidth + x) * 4];
                    for (int channel = 0; channel < 3; ++channel)
                    {
                        target[channel] = alphaSum > 0 ? (unsigned char)((sum[channel] + alphaSum / 2) / alphaSum) : 0;
                    }
                    target[3] = (unsigned char)((alphaSum + count / 2) / count);
                }
            }
            pixels.swap(result);
            *width = newWidth;
            *height = newHeight;
        }

        unsigned char reduced(unsigned char value, int bits)
        {
            int levels = (1 << bits) - 1;
            int step = (value * levels + 127) / 255;
            return (unsigned char)((step * 255 + levels / 2) / levels);
        }

        bool quantize(std::vector<unsigned char> &pixels, int format)
        {
            bool isTranslucent = false;
            for (size_t offset = 0; offset < pixels.size(); offset += 4)
            {
                if (format == 1)
                {
                    for (int channel = 0; channel < 4; ++channel)
                    {
                        pixels[offset + channel] = reduced(pixels[offset + channel], 4);
                    }
                }
                else if (format == 2)
                {
                    pixels[offset] = reduced(pixels[offset], 5);
                    pixels[offset + 1] = reduced(pixels[offset + 1], 6);
                    pixels[offset + 2] = reduced(pixels[offset + 2], 5);
                    isTranslucent = isTranslucent || pixels[offset + 3] != 255;
                    pixels[offset + 3] = 255;
                }
            }
            return isTranslucent;
        }
    }

    bool changesImage(const ImageSettings &settings)
    {
        return settings.m_maxSize > 0 || settings.m_filter != 0 || settings.m_format != 0;
    }

    bool convertImage(const std::vector<unsigned char> &file, const ImageSettings &settings, std::vector<unsigned char> *out, std::string *warning, std::string *error)
    {
        int width = 0, height = 0, channels = 0;
        unsigned char *decoded = stbi_load_from_memory(file.data(), (int)file.size(), &width, &height, &channels, 4);
        if (!decoded)
        {
            *error = stbi_failure_reason();
            return false;
        }
        std::vector<unsigned char> pixels(decoded, decoded + (size_t)width * height * 4);
        stbi_image_free(decoded);

        int sourceWidth = width;
        int sourceHeight = height;
        while (settings.m_maxSize > 0 && (width > settings.m_maxSize || height > settings.m_maxSize) && width > 1 && height > 1)
        {
            halve(pixels, &width, &height);
        }
        if (quantize(pixels, settings.m_format))
        {
            *warning = "has transparent pixels, which rgb565 cannot keep, so they are opaque";
        }

        int length = 0;
        unsigned char *encoded = stbi_write_png_to_mem(pixels.data(), width * 4, width, height, 4, &length);
        if (!encoded)
        {
            *error = "could not write the PNG";
            return false;
        }
        std::vector<unsigned char> png(encoded, encoded + length);
        STBIW_FREE(encoded);

        std::vector<unsigned char> chunk;
        putBigEndian(chunk, 10);
        const unsigned char name[4] = {'f', 'r', 'I', 'm'};
        chunk.insert(chunk.end(), name, name + 4);
        putBigEndian(chunk, (uint32_t)sourceWidth);
        putBigEndian(chunk, (uint32_t)sourceHeight);
        chunk.push_back((unsigned char)settings.m_filter);
        chunk.push_back((unsigned char)settings.m_format);
        putBigEndian(chunk, crc32Of(chunk.data() + 4, chunk.size() - 4));

        // The signature is 8 bytes and IHDR, with its length, type, 13 bytes of data and CRC, 25.
        const size_t afterHeader = 8 + 25;
        out->assign(png.begin(), png.begin() + afterHeader);
        out->insert(out->end(), chunk.begin(), chunk.end());
        out->insert(out->end(), png.begin() + afterHeader, png.end());
        return true;
    }
}
