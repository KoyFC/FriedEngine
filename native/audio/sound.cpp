#include "audio/sound.h"

#include <SDL_mixer.h>
#include <vector>

namespace
{
    std::vector<Mix_Chunk *> s_sounds;
    std::vector<int> s_freeSoundIds;

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

    Mix_Chunk *soundAt(int soundId)
    {
        if (soundId < 0 || soundId >= (int)s_sounds.size())
        {
            return nullptr;
        }
        return s_sounds[soundId];
    }
}

int fried_sound_load(const char *path)
{
    if (!path)
    {
        return -1;
    }

    Mix_Chunk *sound = Mix_LoadWAV(path);
    if (!sound)
    {
        return -1;
    }

    if (!s_freeSoundIds.empty())
    {
        int soundId = s_freeSoundIds.back();
        s_freeSoundIds.pop_back();
        s_sounds[soundId] = sound;
        return soundId;
    }

    s_sounds.push_back(sound);
    return (int)(s_sounds.size() - 1);
}

void fried_sound_destroy(int soundId)
{
    Mix_Chunk *sound = soundAt(soundId);
    if (!sound)
    {
        return;
    }

    fried_sound_stop(soundId);
    Mix_FreeChunk(sound);
    s_sounds[soundId] = nullptr;
    s_freeSoundIds.push_back(soundId);
}

void fried_sound_play(int soundId, int loops)
{
    Mix_Chunk *sound = soundAt(soundId);
    if (!sound)
    {
        return;
    }
    Mix_PlayChannel(-1, sound, loops);
}

void fried_sound_stop(int soundId)
{
    Mix_Chunk *sound = soundAt(soundId);
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
    Mix_Chunk *sound = soundAt(soundId);
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
    Mix_Chunk *sound = soundAt(soundId);
    if (!sound)
    {
        return;
    }
    Mix_VolumeChunk(sound, toMixVolume(volume));
}

double fried_sound_get_volume(int soundId)
{
    Mix_Chunk *sound = soundAt(soundId);
    if (!sound)
    {
        return 0.0;
    }
    return Mix_VolumeChunk(sound, -1) / (double)MIX_MAX_VOLUME;
}
