#include "audio/music.h"

#include <SDL_mixer.h>
#include <vector>

namespace
{
    std::vector<Mix_Music *> s_music;
    std::vector<int> s_freeMusicIds;

    int s_musicIdOnStream = -1;

    int toMixVolume(double volume)
    {
        if (volume < 0.0)
        {
            volume = 0.0;
        }
        else if (volume > 1.0)
        {
            volume = 1.0;
        }
        return (int)(volume * MIX_MAX_VOLUME + 0.5);
    }

    bool isOnStream(int musicId)
    {
        return musicId >= 0 && musicId == s_musicIdOnStream && Mix_PlayingMusic() != 0;
    }

    Mix_Music *musicAt(int musicId)
    {
        if (musicId < 0 || musicId >= (int)s_music.size())
        {
            return nullptr;
        }
        return s_music[musicId];
    }
}

int fried_music_load(const char *path)
{
    if (!path)
    {
        return -1;
    }

    Mix_Music *music = Mix_LoadMUS(path);
    if (!music)
    {
        return -1;
    }

    if (!s_freeMusicIds.empty())
    {
        int musicId = s_freeMusicIds.back();
        s_freeMusicIds.pop_back();
        s_music[musicId] = music;
        return musicId;
    }

    s_music.push_back(music);
    return (int)(s_music.size() - 1);
}

void fried_music_destroy(int musicId)
{
    Mix_Music *music = musicAt(musicId);
    if (!music)
    {
        return;
    }

    fried_music_stop(musicId);
    Mix_FreeMusic(music);
    s_music[musicId] = nullptr;
    s_freeMusicIds.push_back(musicId);
}

void fried_music_play(int musicId, int loops)
{
    Mix_Music *music = musicAt(musicId);
    if (!music)
    {
        return;
    }
    if (Mix_PlayMusic(music, loops) != 0)
    {
        return;
    }
    s_musicIdOnStream = musicId;
}

void fried_music_pause(int musicId)
{
    if (!isOnStream(musicId))
    {
        return;
    }
    Mix_PauseMusic();
}

void fried_music_resume(int musicId)
{
    if (!isOnStream(musicId))
    {
        return;
    }
    Mix_ResumeMusic();
}

void fried_music_stop(int musicId)
{
    if (!isOnStream(musicId))
    {
        return;
    }
    Mix_HaltMusic();
    s_musicIdOnStream = -1;
}

bool fried_music_is_playing(int musicId)
{
    return isOnStream(musicId) && Mix_PausedMusic() == 0;
}

bool fried_music_is_paused(int musicId)
{
    return isOnStream(musicId) && Mix_PausedMusic() != 0;
}

void fried_music_set_volume(double volume)
{
    Mix_VolumeMusic(toMixVolume(volume));
}

double fried_music_get_volume()
{
    return Mix_VolumeMusic(-1) / (double)MIX_MAX_VOLUME;
}
