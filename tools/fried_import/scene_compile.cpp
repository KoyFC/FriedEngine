#include "scene_compile.h"

#include <cstring>
#include <map>

namespace fried_import
{
    namespace
    {
        const int s_sceneVersion = 3;
        const unsigned short s_format = 1;

        enum Tag : unsigned char
        {
            TagNull = 0,
            TagFalse = 1,
            TagTrue = 2,
            TagInt = 3,
            TagFloat32 = 4,
            TagFloat64 = 5,
            TagString = 6,
            TagArray = 7,
            TagObject = 8
        };

        class Writer
        {
        public:
            std::vector<unsigned char> m_bytes;
            std::vector<std::string> m_strings;
            std::map<std::string, unsigned> m_indices;

            void collect(const Value &value)
            {
                switch (value.m_kind)
                {
                case Value::Kind::String:
                    intern(value.m_string);
                    break;
                case Value::Kind::Array:
                    for (const Value &item : value.m_array)
                    {
                        collect(item);
                    }
                    break;
                case Value::Kind::Object:
                    for (const auto &pair : value.m_object)
                    {
                        intern(pair.first);
                        collect(pair.second);
                    }
                    break;
                default:
                    break;
                }
            }

            void writeAll(const Value &root)
            {
                const char magic[4] = {'F', 'S', 'C', 'N'};
                m_bytes.insert(m_bytes.end(), magic, magic + 4);
                u16(s_format);
                u16(s_sceneVersion);
                u32((unsigned)m_strings.size());
                for (const std::string &text : m_strings)
                {
                    u32((unsigned)text.size());
                    m_bytes.insert(m_bytes.end(), text.begin(), text.end());
                }
                while (m_bytes.size() % 4 != 0)
                {
                    m_bytes.push_back(0);
                }
                value(root);
            }

        private:
            unsigned intern(const std::string &text)
            {
                auto found = m_indices.find(text);
                if (found != m_indices.end())
                {
                    return found->second;
                }
                unsigned index = (unsigned)m_strings.size();
                m_strings.push_back(text);
                m_indices[text] = index;
                return index;
            }

            void u8(unsigned char v)
            {
                m_bytes.push_back(v);
            }

            void u16(unsigned v)
            {
                u8(v & 0xFF);
                u8((v >> 8) & 0xFF);
            }

            void u32(unsigned v)
            {
                u16(v & 0xFFFF);
                u16((v >> 16) & 0xFFFF);
            }

            void value(const Value &v)
            {
                switch (v.m_kind)
                {
                case Value::Kind::Null:
                    u8(TagNull);
                    break;
                case Value::Kind::Bool:
                    u8(v.m_bool ? TagTrue : TagFalse);
                    break;
                case Value::Kind::Number:
                    number(v);
                    break;
                case Value::Kind::String:
                    u8(TagString);
                    u32(intern(v.m_string));
                    break;
                case Value::Kind::Array:
                    u8(TagArray);
                    u32((unsigned)v.m_array.size());
                    for (const Value &item : v.m_array)
                    {
                        value(item);
                    }
                    break;
                case Value::Kind::Object:
                    u8(TagObject);
                    u32((unsigned)v.m_object.size());
                    for (const auto &pair : v.m_object)
                    {
                        u32(intern(pair.first));
                        value(pair.second);
                    }
                    break;
                }
            }

            void number(const Value &v)
            {
                if (v.m_isInteger)
                {
                    u8(TagInt);
                    u32((unsigned)(int)v.m_number);
                    return;
                }
                float single = (float)v.m_number;
                if ((double)single == v.m_number)
                {
                    u8(TagFloat32);
                    unsigned bits;
                    std::memcpy(&bits, &single, 4);
                    u32(bits);
                    return;
                }
                u8(TagFloat64);
                unsigned long long bits;
                std::memcpy(&bits, &v.m_number, 8);
                u32((unsigned)(bits & 0xFFFFFFFFu));
                u32((unsigned)(bits >> 32));
            }
        };
    }

    bool compileScene(const Value &scene, const std::string &name, std::vector<unsigned char> *bytes, std::string *error)
    {
        if (scene.m_kind != Value::Kind::Object)
        {
            *error = "the scene is not a map of keys and values";
            return false;
        }
        const Value *version = scene.find("version");
        if (!version || version->m_kind != Value::Kind::Number || (int)version->m_number != s_sceneVersion)
        {
            *error = "the scene is not version " + std::to_string(s_sceneVersion) + ", which is the one this engine reads: bring it up to date with fried_import migrate-scenes";
            return false;
        }
        const Value *nodes = scene.find("objects");
        if (!nodes || nodes->m_kind != Value::Kind::Array)
        {
            *error = "the scene has no objects list";
            return false;
        }
        if (nodes->m_array.size() != 1)
        {
            *error = "the scene " + name + " has " + std::to_string(nodes->m_array.size()) +
                     " top-level objects, and a scene has exactly one root object: put them under a new root object, which the editor does when it opens the file";
            return false;
        }
        Writer writer;
        writer.collect(scene);
        writer.writeAll(scene);
        *bytes = std::move(writer.m_bytes);
        return true;
    }
}
