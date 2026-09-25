#include "platform.h"

#include <SDL.h>
#include <string>

namespace
{
    std::string s_basePath;
    std::string s_assetPath;

    std::string resolveAssetPath(const std::string &basePath)
    {
        return basePath + "assets/";
    }
}

void fried_platform_init()
{
    char *basePath = SDL_GetBasePath();
    if (basePath)
    {
        s_basePath = basePath;
        SDL_free(basePath);
    }
    else
    {
        s_basePath = "./";
    }

    s_assetPath = resolveAssetPath(s_basePath);
}

const char *fried_platform_get_base_path()
{
    return s_basePath.c_str();
}

const char *fried_platform_get_asset_path()
{
    return s_assetPath.c_str();
}
