#include "import_settings.h"

#include <cctype>
#include <cstdlib>
#include <map>
#include <memory>
#include <vector>

namespace fried_import
{
    namespace
    {
        struct Value
        {
            enum class Kind
            {
                Null,
                Bool,
                Number,
                String,
                Array,
                Object
            };
            Kind m_kind = Kind::Null;
            bool m_bool = false;
            double m_number = 0;
            std::string m_string;
            std::vector<Value> m_array;
            std::map<std::string, Value> m_object;

            const Value *find(const std::string &key) const
            {
                auto found = m_object.find(key);
                return m_kind == Kind::Object && found != m_object.end() ? &found->second : nullptr;
            }
        };

        class Parser
        {
        public:
            Parser(const std::string &text)
                : m_text(text)
            {
            }

            bool parse(Value *value, std::string *error)
            {
                if (!read(value) || (skip(), m_at != m_text.size()))
                {
                    *error = m_error.empty() ? "unexpected text after the value" : m_error;
                    return false;
                }
                return true;
            }

        private:
            void skip()
            {
                while (m_at < m_text.size() && std::isspace((unsigned char)m_text[m_at]))
                {
                    ++m_at;
                }
            }

            bool fail(const char *message)
            {
                m_error = message;
                return false;
            }

            bool read(Value *value)
            {
                skip();
                if (m_at >= m_text.size())
                {
                    return fail("the text ends too soon");
                }
                char c = m_text[m_at];
                if (c == '{')
                {
                    ++m_at;
                    value->m_kind = Value::Kind::Object;
                    skip();
                    if (m_at < m_text.size() && m_text[m_at] == '}')
                    {
                        ++m_at;
                        return true;
                    }
                    for (;;)
                    {
                        skip();
                        Value key;
                        if (m_at >= m_text.size() || m_text[m_at] != '"' || !read(&key))
                        {
                            return fail("an object's name is not a string");
                        }
                        skip();
                        if (m_at >= m_text.size() || m_text[m_at++] != ':')
                        {
                            return fail("a ':' is missing");
                        }
                        if (!read(&value->m_object[key.m_string]))
                        {
                            return false;
                        }
                        skip();
                        if (m_at < m_text.size() && m_text[m_at] == ',')
                        {
                            ++m_at;
                            continue;
                        }
                        if (m_at < m_text.size() && m_text[m_at] == '}')
                        {
                            ++m_at;
                            return true;
                        }
                        return fail("a ',' or '}' is missing");
                    }
                }
                if (c == '[')
                {
                    ++m_at;
                    value->m_kind = Value::Kind::Array;
                    skip();
                    if (m_at < m_text.size() && m_text[m_at] == ']')
                    {
                        ++m_at;
                        return true;
                    }
                    for (;;)
                    {
                        value->m_array.emplace_back();
                        if (!read(&value->m_array.back()))
                        {
                            return false;
                        }
                        skip();
                        if (m_at < m_text.size() && m_text[m_at] == ',')
                        {
                            ++m_at;
                            continue;
                        }
                        if (m_at < m_text.size() && m_text[m_at] == ']')
                        {
                            ++m_at;
                            return true;
                        }
                        return fail("a ',' or ']' is missing");
                    }
                }
                if (c == '"')
                {
                    ++m_at;
                    value->m_kind = Value::Kind::String;
                    while (m_at < m_text.size() && m_text[m_at] != '"')
                    {
                        if (m_text[m_at] == '\\' && m_at + 1 < m_text.size())
                        {
                            ++m_at;
                        }
                        value->m_string += m_text[m_at++];
                    }
                    if (m_at >= m_text.size())
                    {
                        return fail("a string is not closed");
                    }
                    ++m_at;
                    return true;
                }
                if (m_text.compare(m_at, 4, "true") == 0 || m_text.compare(m_at, 5, "false") == 0)
                {
                    value->m_kind = Value::Kind::Bool;
                    value->m_bool = m_text[m_at] == 't';
                    m_at += value->m_bool ? 4 : 5;
                    return true;
                }
                if (m_text.compare(m_at, 4, "null") == 0)
                {
                    m_at += 4;
                    return true;
                }
                char *end = nullptr;
                value->m_number = std::strtod(m_text.c_str() + m_at, &end);
                if (end == m_text.c_str() + m_at)
                {
                    return fail("a value is expected");
                }
                value->m_kind = Value::Kind::Number;
                m_at = (size_t)(end - m_text.c_str());
                return true;
            }

            const std::string &m_text;
            size_t m_at = 0;
            std::string m_error;
        };

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
        if (!Parser(text).parse(&root, error))
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
