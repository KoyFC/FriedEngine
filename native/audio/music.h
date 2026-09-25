#pragma once

extern "C"
{
    int fried_music_load(const char *path);
    void fried_music_destroy(int musicId);

    void fried_music_play(int musicId, int loops);
    void fried_music_pause(int musicId);
    void fried_music_resume(int musicId);
    void fried_music_stop(int musicId);
    bool fried_music_is_playing(int musicId);
    bool fried_music_is_paused(int musicId);

    void fried_music_set_volume(double volume);
    double fried_music_get_volume();
}
