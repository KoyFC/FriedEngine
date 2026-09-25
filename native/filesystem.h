#pragma once

extern "C"
{
    void fried_filesystem_init();
    const char *fried_filesystem_get_base_path();
    const char *fried_filesystem_get_asset_path();
}
