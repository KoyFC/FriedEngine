#include "audio/sound.h"

#include "handle_pool.h"
#include "last_error.h"

#include <SDL_mixer.h>

namespace
{
    HandlePool<Mix_Chunk> s_sounds;

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

}

int fried_sound_load(const char *path)
{
    if (!path)
    {
        fried_set_last_error("No path given");
        return -1;
    }

    Mix_Chunk *sound = Mix_LoadWAV(path);
    if (!sound)
    {
        fried_capture_sdl_error();
        return -1;
    }

    return s_sounds.store(sound);
}

void fried_sound_destroy(int soundId)
{
    fried_sound_stop(soundId);

    Mix_Chunk *sound = s_sounds.release(soundId);
    if (!sound)
    {
        return;
    }

    Mix_FreeChunk(sound);
}

void fried_sound_play(int soundId, int loops)
{
    Mix_Chunk *sound = s_sounds.get(soundId);
    if (!sound)
    {
        return;
    }
    Mix_PlayChannel(-1, sound, loops);
}

void fried_sound_stop(int soundId)
{
    Mix_Chunk *sound = s_sounds.get(soundId);
    if (!sound)
    {
        return;
    }

    int channelCount = Mix_AllocateChannels(-1);
    for (int channel = 0; channel < channelCount; ++channel)
    {
        if (Mix_GetChunk(channel) == sound && Mix_Playing(channel))
        {
            Mix_HaltChannel(channel);
        }
    }
}

bool fried_sound_is_playing(int soundId)
{
    Mix_Chunk *sound = s_sounds.get(soundId);
    if (!sound)
    {
        return false;
    }

    int channelCount = Mix_AllocateChannels(-1);
    for (int channel = 0; channel < channelCount; ++channel)
    {
        if (Mix_GetChunk(channel) == sound && Mix_Playing(channel))
        {
            return true;
        }
    }
    return false;
}

void fried_sound_set_volume(int soundId, double volume)
{
    Mix_Chunk *sound = s_sounds.get(soundId);
    if (!sound)
    {
        return;
    }
    Mix_VolumeChunk(sound, toMixVolume(volume));
}

double fried_sound_get_volume(int soundId)
{
    Mix_Chunk *sound = s_sounds.get(soundId);
    if (!sound)
    {
        return 0.0;
    }
    return Mix_VolumeChunk(sound, -1) / (double)MIX_MAX_VOLUME;
}
