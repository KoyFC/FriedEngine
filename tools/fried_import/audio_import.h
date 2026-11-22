#pragma once

#include "import_settings.h"

#include <string>
#include <vector>

namespace fried_import
{
    bool changesAudio(const AudioSettings &settings);

    // Reads a PCM WAV file of 8 or 16 bits and writes it again mixed down to one channel, at another rate and in another depth, as the settings ask.
    bool convertWav(const std::vector<unsigned char> &file, const AudioSettings &settings, std::vector<unsigned char> *out, std::string *error);
}
