#include "lz10.h"

namespace fried_import
{
    namespace
    {
        const int s_window = 4096;
        const int s_minMatch = 3;
        const int s_maxMatch = 18;
        const int s_chain = 64;
        const int s_hashBits = 15;

        unsigned hashAt(const unsigned char *p)
        {
            return ((p[0] << 10) ^ (p[1] << 5) ^ p[2]) & ((1u << s_hashBits) - 1);
        }
    }

    std::vector<unsigned char> compressLz10(const std::vector<unsigned char> &in)
    {
        const size_t n = in.size();
        if (n == 0 || n >= (1u << 24))
        {
            return {};
        }
        std::vector<unsigned char> out = {'F', 'R', 'L', 'Z', 0x10, (unsigned char)(n & 0xFF), (unsigned char)((n >> 8) & 0xFF), (unsigned char)((n >> 16) & 0xFF)};
        std::vector<int> head(1u << s_hashBits, -1);
        std::vector<int> previous(n, -1);

        auto insert = [&](size_t at) {
            if (at + s_minMatch <= n)
            {
                unsigned h = hashAt(&in[at]);
                previous[at] = head[h];
                head[h] = (int)at;
            }
        };

        size_t at = 0;
        while (at < n)
        {
            size_t flagsAt = out.size();
            out.push_back(0);
            for (int bit = 0; bit < 8 && at < n; ++bit)
            {
                int bestLength = 0, bestDistance = 0;
                if (at + s_minMatch <= n)
                {
                    int candidate = head[hashAt(&in[at])];
                    int steps = 0;
                    int limit = (int)(n - at < (size_t)s_maxMatch ? n - at : (size_t)s_maxMatch);
                    while (candidate >= 0 && (int)at - candidate <= s_window && steps++ < s_chain)
                    {
                        int length = 0;
                        while (length < limit && in[candidate + length] == in[at + length])
                        {
                            ++length;
                        }
                        if (length > bestLength)
                        {
                            bestLength = length;
                            bestDistance = (int)at - candidate;
                            if (length == limit)
                            {
                                break;
                            }
                        }
                        candidate = previous[candidate];
                    }
                }
                if (bestLength >= s_minMatch)
                {
                    out[flagsAt] |= (unsigned char)(0x80 >> bit);
                    out.push_back((unsigned char)(((bestLength - s_minMatch) << 4) | ((bestDistance - 1) >> 8)));
                    out.push_back((unsigned char)((bestDistance - 1) & 0xFF));
                    for (int i = 0; i < bestLength; ++i)
                    {
                        insert(at + i);
                    }
                    at += bestLength;
                }
                else
                {
                    out.push_back(in[at]);
                    insert(at);
                    ++at;
                }
            }
        }
        return out;
    }
}
