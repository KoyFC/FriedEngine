#pragma once

extern "C"
{
    void fried_filesystem_init();
    void fried_filesystem_shutdown();
    const char *fried_filesystem_get_base_path();
    const char *fried_filesystem_get_asset_path();

    void fried_filesystem_init_user_data(const char *organization, const char *name);
    const char *fried_filesystem_get_user_data_path();
}
