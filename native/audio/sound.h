#pragma once

extern "C"
{
    int fried_sound_load(const char *path);
    void fried_sound_destroy(int soundId);

    void fried_sound_play(int soundId, int loops);
    void fried_sound_stop(int soundId);
    bool fried_sound_is_playing(int soundId);

    void fried_sound_set_volume(int soundId, double volume);
    double fried_sound_get_volume(int soundId);
}
