#include "platform/filesystem.h"

#include "last_error.h"

#include <SDL.h>
#include <string>

#ifdef __SWITCH__
#include <switch.h>
#elif defined(__3DS__)
#include <3ds.h>
#endif

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
#elif defined(__SWITCH__) || defined(__3DS__)
    // The Switch and the 3DS read their assets out of the .nro or .3dsx, through
    // the romfs mounted below. Unlike the Vita's, that mount is not automatic.
    std::string resolveAssetPath(const std::string &)
    {
        return "romfs:/assets/";
    }
#else
    std::string resolveAssetPath(const std::string &basePath)
    {
        return basePath + "assets/";
    }
#endif

#ifdef __SWITCH__
    // SDL's Switch port uses its dummy filesystem backend, so SDL_GetPrefPath()
    // answers nothing there. sdmc:/switch/ is the flat list of one directory per
    // homebrew application that the console already keeps, so the organization
    // has nowhere to go.
    std::string resolveUserDataPath(const char *, const char *name)
    {
        return std::string("sdmc:/switch/") + name + "/";
    }
#else
    std::string resolveUserDataPath(const char *organization, const char *name)
    {
        char *userDataPath = SDL_GetPrefPath(organization, name);
        if (!userDataPath)
        {
            fried_capture_sdl_error();
            return std::string();
        }

        std::string resolved = userDataPath;
        SDL_free(userDataPath);
        return resolved;
    }
#endif
}

void fried_filesystem_init()
{
#if defined(__SWITCH__) || defined(__3DS__)
    romfsInit();
#endif

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

void fried_filesystem_shutdown()
{
#if defined(__SWITCH__) || defined(__3DS__)
    romfsExit();
#endif
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
    s_userDataPath = resolveUserDataPath(organization, name);
}

const char *fried_filesystem_get_user_data_path()
{
    return s_userDataPath.c_str();
}
