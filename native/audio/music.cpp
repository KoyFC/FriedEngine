#include "audio/music.h"

#include "handle_pool.h"
#include "last_error.h"

#include <SDL_mixer.h>

namespace
{
    HandlePool<Mix_Music> s_music;

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

}

int fried_music_load(const char *path)
{
    if (!path)
    {
        fried_set_last_error("No path given");
        return -1;
    }

    Mix_Music *music = Mix_LoadMUS(path);
    if (!music)
    {
        fried_capture_sdl_error();
        return -1;
    }

    return s_music.store(music);
}

void fried_music_destroy(int musicId)
{
    fried_music_stop(musicId);

    Mix_Music *music = s_music.release(musicId);
    if (!music)
    {
        return;
    }

    Mix_FreeMusic(music);
}

void fried_music_play(int musicId, int loops)
{
    Mix_Music *music = s_music.get(musicId);
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
