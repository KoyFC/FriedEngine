#pragma once

#include <functional>
#include <string>
#include <vector>

namespace fried_model
{
    struct Options
    {
        std::function<std::string(const std::vector<unsigned char> &png, const std::string &name)> m_extract;

        bool m_stripImages = false;
    };

    struct Result
    {
        std::vector<unsigned char> m_bytes;

        std::vector<std::string> m_dependencies;
        std::vector<std::string> m_warnings;
        int m_triangleCount = 0;
        int m_vertexCount = 0;
    };

    bool convert(const std::string &path, const Options &options, Result *result, std::string *error);
}
