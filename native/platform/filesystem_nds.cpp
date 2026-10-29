#include "platform/filesystem.h"

#include "last_error.h"

#include <fat.h>
#include <filesystem.h>
#include <sys/iosupport.h>

#include <string>

// The assets are read out of the ROM through NitroFS. User data goes to a FAT
// volume, which is the DSi's SD card where there is one and otherwise the
// flashcart's, reached through its DLDI driver.

namespace
{
    std::string s_userDataPath;

    std::string writableRoot()
    {
        if (!fatInitDefault())
        {
            return std::string();
        }
        return FindDevice("sd:") >= 0 ? "sd:/" : "fat:/";
    }
}

void fried_filesystem_init()
{
    nitroFSInit(nullptr);
}

void fried_filesystem_shutdown()
{
}

const char *fried_filesystem_get_base_path()
{
    return "nitro:/";
}

const char *fried_filesystem_get_asset_path()
{
    return "nitro:/assets/";
}

// /data/<name>/ is where DS homebrew keeps its files, one directory each, so
// the organization has nowhere to go.
void fried_filesystem_init_user_data(const char *, const char *name)
{
    std::string root = writableRoot();
    if (root.empty())
    {
        fried_set_last_error("No FAT volume: the DS has one through a flashcart's DLDI driver or the DSi's SD card");
        s_userDataPath.clear();
        return;
    }
    s_userDataPath = root + "data/" + name + "/";
}

const char *fried_filesystem_get_user_data_path()
{
    return s_userDataPath.c_str();
}
