// Where stb_image and stb_image_write are made, for the converter: no other
// file of a game on PC reads or writes an image with them.
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "third_party/stb_image.h"
#include "third_party/stb_image_write.h"

#include "model/model_native.h"

#include "last_error.h"
#include "model/model_convert.h"

#include <string>
#include <vector>

namespace
{
    std::vector<std::vector<unsigned char>> s_converted;
    std::vector<bool> s_isUsed;
}

int fried_model_convert_file(const char *path)
{
    if (!path)
    {
        fried_set_last_error("No path given");
        return -1;
    }
    fried_model::Options options;
    fried_model::Result result;
    std::string error;
    if (!fried_model::convert(path, options, &result, &error))
    {
        fried_set_last_error(error.c_str());
        return -1;
    }

    for (size_t handle = 0; handle < s_converted.size(); ++handle)
    {
        if (!s_isUsed[handle])
        {
            s_converted[handle] = std::move(result.m_bytes);
            s_isUsed[handle] = true;
            return (int)handle;
        }
    }
    s_converted.push_back(std::move(result.m_bytes));
    s_isUsed.push_back(true);
    return (int)s_converted.size() - 1;
}

int fried_model_get_size(int handle)
{
    return handle >= 0 && handle < (int)s_converted.size() && s_isUsed[handle] ? (int)s_converted[handle].size() : -1;
}

void fried_model_copy(int handle, unsigned char *out)
{
    if (handle >= 0 && handle < (int)s_converted.size() && s_isUsed[handle] && out)
    {
        std::copy(s_converted[handle].begin(), s_converted[handle].end(), out);
    }
}

void fried_model_release(int handle)
{
    if (handle >= 0 && handle < (int)s_converted.size() && s_isUsed[handle])
    {
        s_isUsed[handle] = false;
        std::vector<unsigned char>().swap(s_converted[handle]);
    }
}
