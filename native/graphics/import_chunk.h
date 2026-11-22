#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>

// What tools/fried_import wrote into a PNG, in a "frIm" chunk before the image's data: the size the source had, which the file may be smaller than, how its texture is filtered and the depth of its colors.
struct FriedImportInfo
{
    bool m_isPresent = false;
    int m_width = 0;
    int m_height = 0;
    // 0 is the project's own, 1 nearest and 2 linear.
    int m_filter = 0;
    // 0 is 8 bits a channel, 1 is 4 and 2 is 5, 6 and 5 without alpha.
    int m_format = 0;
};

inline FriedImportInfo fried_read_import_chunk(const unsigned char *png, size_t size)
{
    FriedImportInfo info;
    static const unsigned char signature[8] = {0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a};
    if (!png || size < 8 || std::memcmp(png, signature, 8) != 0)
    {
        return info;
    }
    auto bigEndian = [](const unsigned char *at) { return ((uint32_t)at[0] << 24) | ((uint32_t)at[1] << 16) | ((uint32_t)at[2] << 8) | at[3]; };
    size_t at = 8;
    while (at + 12 <= size)
    {
        uint32_t length = bigEndian(png + at);
        const unsigned char *type = png + at + 4;
        if (std::memcmp(type, "IDAT", 4) == 0)
        {
            break;
        }
        if (std::memcmp(type, "frIm", 4) == 0 && length >= 10 && at + 12 + length <= size)
        {
            info.m_isPresent = true;
            info.m_width = (int)bigEndian(png + at + 8);
            info.m_height = (int)bigEndian(png + at + 12);
            info.m_filter = png[at + 16];
            info.m_format = png[at + 17];
            break;
        }
        at += 12 + (size_t)length;
    }
    return info;
}

// The power of two the source's width was halved by to give the loaded width, which the tool halves the height by too. 1 for a file that was not imported or is not smaller.
inline int fried_import_downscale(const FriedImportInfo &info, int loadedWidth)
{
    if (!info.m_isPresent || loadedWidth <= 0)
    {
        return 1;
    }
    for (int downscale = 1; downscale <= 4096; downscale *= 2)
    {
        if ((info.m_width + downscale - 1) / downscale == loadedWidth)
        {
            return downscale;
        }
    }
    return 1;
}
