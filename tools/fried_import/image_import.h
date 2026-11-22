#pragma once

#include "import_settings.h"

#include <string>
#include <vector>

namespace fried_import
{
    // Whether the settings ask for anything a copy would not do.
    bool changesImage(const ImageSettings &settings);

    // Brings a PNG under the settings' size, takes its colors to the format's depth and writes it again with a "frIm" chunk after the header that holds the size of the source, the filter and the format, which the engine reads when it loads the file.
    bool convertImage(const std::vector<unsigned char> &file, const ImageSettings &settings, std::vector<unsigned char> *out, std::string *warning, std::string *error);
}
