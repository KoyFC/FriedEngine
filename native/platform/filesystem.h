#pragma once

extern "C"
{
    void fried_filesystem_init();
    void fried_filesystem_shutdown();
    const char *fried_filesystem_get_base_path();
    const char *fried_filesystem_get_asset_path();

    void fried_filesystem_init_user_data(const char *organization, const char *name);
    const char *fried_filesystem_get_user_data_path();

    // 1 where assets are read through SDL rather than as files: Android, whose assets are inside the APK.
    int fried_filesystem_assets_are_packed();
    int fried_filesystem_exists(const char *path);
    // Reads a whole file and keeps it until fried_filesystem_take_loaded(). Returns its size, or -1 with the error captured.
    int fried_filesystem_load(const char *path);
    // Copies the file fried_filesystem_load() read into destination, which holds its size, and lets it go. A null destination only lets it go.
    void fried_filesystem_take_loaded(unsigned char *destination);
}
