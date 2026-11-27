#pragma once

#include <vector>

namespace fried_import
{
    // The bytes as a compressed asset, or nothing when they are empty or too long for the format (16 MiB).
    std::vector<unsigned char> compressLz10(const std::vector<unsigned char> &bytes);
}
