#include "platform/filesystem.h"

#include <string>

// A game is a .g3a next to a folder of the same name at the root of the
// calculator's storage memory, which holds its assets and its user data.

#ifndef FRIED_CG50_DIRECTORY
#error "FRIED_CG50_DIRECTORY names the game's folder; fried_add_game() defines it from project.fried"
#endif

namespace
{
    const std::string s_basePath = std::string("/") + FRIED_CG50_DIRECTORY + "/";
    const std::string s_assetPath = s_basePath + "assets/";
    const std::string s_userDataPath = s_basePath + "data/";
}

void fried_filesystem_init()
{
}

void fried_filesystem_shutdown()
{
}

const char *fried_filesystem_get_base_path()
{
    return s_basePath.c_str();
}

const char *fried_filesystem_get_asset_path()
{
    return s_assetPath.c_str();
}

void fried_filesystem_init_user_data(const char *, const char *)
{
}

const char *fried_filesystem_get_user_data_path()
{
    return s_userDataPath.c_str();
}
