#include "import_settings.h"

#include "yaml.h"

namespace fried_import
{
    namespace
    {
        int integerOf(const Value *value, int fallback)
        {
            return value && value->m_kind == Value::Kind::Number ? (int)value->m_number : fallback;
        }

        void applyImage(const Value &image, ImageSettings *settings)
        {
            settings->m_maxSize = integerOf(image.find("maxSize"), settings->m_maxSize);
            if (const Value *filter = image.find("filter"); filter && filter->m_kind == Value::Kind::String)
            {
                settings->m_filter = filter->m_string == "nearest" ? 1 : (filter->m_string == "linear" ? 2 : 0);
            }
            if (const Value *format = image.find("format"); format && format->m_kind == Value::Kind::String)
            {
                settings->m_format = format->m_string == "rgba4" ? 1 : (format->m_string == "rgb565" ? 2 : 0);
            }
        }

        void applyAudio(const Value &audio, AudioSettings *settings)
        {
            if (const Value *mono = audio.find("mono"); mono && mono->m_kind == Value::Kind::Bool)
            {
                settings->m_mono = mono->m_bool;
            }
            settings->m_sampleRate = integerOf(audio.find("sampleRate"), settings->m_sampleRate);
            settings->m_bits = integerOf(audio.find("bits"), settings->m_bits);
        }

        void applyBlock(const Value &block, Settings *settings)
        {
            if (const Value *compress = block.find("compress"); compress && compress->m_kind == Value::Kind::String)
            {
                settings->m_compress = compress->m_string == "none" ? 1 : (compress->m_string == "lz" ? 2 : 0);
            }
            if (const Value *image = block.find("image"))
            {
                settings->m_hasImage = true;
                applyImage(*image, &settings->m_image);
            }
            if (const Value *audio = block.find("audio"))
            {
                settings->m_hasAudio = true;
                applyAudio(*audio, &settings->m_audio);
            }
        }
    }

    bool parseSettings(const std::string &text, const std::string &platform, Settings *settings, std::string *error)
    {
        Value root;
        if (!parseYaml(text, &root, error))
        {
            return false;
        }
        if (root.m_kind != Value::Kind::Object)
        {
            *error = "the file is not an object";
            return false;
        }
        applyBlock(root, settings);
        if (const Value *platforms = root.find("platforms"))
        {
            if (const Value *block = platforms->find(platform))
            {
                applyBlock(*block, settings);
            }
        }
        return true;
    }
}
