#include "platform/filesystem.h"

#include <SDL.h>
#include <string>

namespace
{
    std::string s_basePath;
    std::string s_assetPath;
    std::string s_userDataPath;

#ifdef __vita__
    // The Vita mounts the application read-only at a fixed point.
    std::string resolveAssetPath(const std::string &)
    {
        return "app0:/assets/";
    }
#else
    std::string resolveAssetPath(const std::string &basePath)
    {
        return basePath + "assets/";
    }
#endif
}

void fried_filesystem_init()
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

const char *fried_filesystem_get_base_path()
{
    return s_basePath.c_str();
}

const char *fried_filesystem_get_asset_path()
{
    return s_assetPath.c_str();
}

void fried_filesystem_init_user_data(const char *organization, const char *name)
{
    char *userDataPath = SDL_GetPrefPath(organization, name);
    if (userDataPath)
    {
        s_userDataPath = userDataPath;
        SDL_free(userDataPath);
    }
}

const char *fried_filesystem_get_user_data_path()
{
    return s_userDataPath.c_str();
}
