#pragma once

#include <string>

namespace fried_import
{
    struct ImageSettings
    {
        // A power of two the longest side is brought under by halving, or 0 for no limit.
        int m_maxSize = 0;
        // 0 the project's own, 1 nearest, 2 linear.
        int m_filter = 0;
        // 0 rgba8, 1 rgba4, 2 rgb565.
        int m_format = 0;
    };

    struct AudioSettings
    {
        bool m_mono = false;
        // 0 keeps the file's.
        int m_sampleRate = 0;
        int m_bits = 0;
    };

    struct Settings
    {
        bool m_hasImage = false;
        bool m_hasAudio = false;
        ImageSettings m_image;
        AudioSettings m_audio;
    };

    // Reads a sidecar's text and works out the settings for a platform: the top level, with the platform's own block laid over it. Returns false with a message when the text is not valid.
    bool parseSettings(const std::string &text, const std::string &platform, Settings *settings, std::string *error);
}
