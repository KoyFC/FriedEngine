#include "lz10.h"

#include <cstring>
#include <new>

int fried_lz10_unpacked_size(const unsigned char *data, int size)
{
    if (size < 8 || std::memcmp(data, "FRLZ", 4) != 0 || data[4] != 0x10)
    {
        return -1;
    }
    return data[5] | (data[6] << 8) | (data[7] << 16);
}

int fried_lz10_unpack(const unsigned char *data, int size, unsigned char *destination, int destinationSize)
{
    if (fried_lz10_unpacked_size(data, size) != destinationSize)
    {
        return 0;
    }
    const unsigned char *in = data + 8;
    const unsigned char *end = data + size;
    unsigned char *out = destination;
    unsigned char *outEnd = destination + destinationSize;
    while (out < outEnd)
    {
        if (in >= end)
        {
            return 0;
        }
        unsigned flags = *in++;
        for (int bit = 0; bit < 8 && out < outEnd; ++bit, flags <<= 1)
        {
            if (flags & 0x80)
            {
                if (end - in < 2)
                {
                    return 0;
                }
                int length = (in[0] >> 4) + 3;
                int distance = (((in[0] & 0x0F) << 8) | in[1]) + 1;
                in += 2;
                if (distance > out - destination || length > outEnd - out)
                {
                    return 0;
                }
                const unsigned char *from = out - distance;
                for (int i = 0; i < length; ++i)
                {
                    *out++ = *from++;
                }
            }
            else
            {
                if (in >= end)
                {
                    return 0;
                }
                *out++ = *in++;
            }
        }
    }
    return 1;
}

bool fried_unpack_asset(unsigned char *&contents, int &size)
{
    int unpacked = fried_lz10_unpacked_size(contents, size);
    if (unpacked < 0)
    {
        return true;
    }
    unsigned char *result = new (std::nothrow) unsigned char[unpacked > 0 ? unpacked : 1];
    if (!result)
    {
        return false;
    }
    if (!fried_lz10_unpack(contents, size, result, unpacked))
    {
        delete[] result;
        return false;
    }
    delete[] contents;
    contents = result;
    size = unpacked;
    return true;
}
