#include "platform.h"

#include <SDL.h>
#include <string>

namespace
{
    std::string s_basePath;
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
}

const char *fried_platform_get_base_path()
{
    return s_basePath.c_str();
}