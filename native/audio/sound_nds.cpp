#include "audio/sound.h"

#include "audio/audio_nds.h"
#include "audio/wave_nds.h"
#include "handle_pool.h"
#include "last_error.h"

#include <fcntl.h>
#include <unistd.h>
#include <nds.h>

#include <algorithm>
#include <cstdint>
#include <memory>
#include <new>

// A sound is a WAV's samples read into main RAM and converted there, which
// the DS's sound hardware plays from there at the file's own rate, mixing the
// channels itself, so playing one costs the ARM9 nothing. Whether one is still
// playing is worked out from when it started and how long it lasts.

namespace
{
    constexpr uint64_t s_forever = UINT64_MAX;

    struct Sound
    {
        std::unique_ptr<uint32_t[]> m_words;
        unsigned m_wordCount;
        SoundFmt m_format;
        unsigned m_rate;
        uint64_t m_durationUs;
        double m_volume;
    };

    // m_soundId is -1 on a channel with nothing playing.
    struct Channel
    {
        int m_soundId;
        bool m_repeats;
        uint64_t m_startUs;
        uint64_t m_endUs;
    };

    HandlePool<Sound> s_sounds;
    Channel s_channels[s_soundChannelCount];

    void stopChannel(int index)
    {
        soundStop(1u << index);
        s_channels[index] = {-1, false, 0, 0};
    }

    // The samples are converted over the data they were read into.
    Sound *readSound(int fd)
    {
        FriedWave wave = {};
        if (!fried_wave_read_header(fd, wave))
        {
            return nullptr;
        }

        Sound *sound = new (std::nothrow) Sound;
        size_t dataBytes = (size_t)wave.m_frames * fried_wave_frame_bytes(wave);
        if (sound)
        {
            sound->m_words.reset(new (std::nothrow) uint32_t[(dataBytes + 3) / 4]);
        }
        if (!sound || !sound->m_words)
        {
            delete sound;
            fried_set_last_error("Not enough memory for the sound");
            return nullptr;
        }
        if (lseek(fd, wave.m_dataOffset, SEEK_SET) != (off_t)wave.m_dataOffset ||
            read(fd, sound->m_words.get(), dataBytes) != (ssize_t)dataBytes)
        {
            delete sound;
            fried_set_last_error("Failed to read the file");
            return nullptr;
        }

        // Mixing a stereo file down leaves the second half of the buffer unused.
        fried_wave_convert(wave, (const uint8_t *)sound->m_words.get(), wave.m_frames, sound->m_words.get());
        sound->m_wordCount = (unsigned)(((size_t)wave.m_frames * fried_wave_sample_bytes(wave) + 3) / 4);
        uint8_t *padding = (uint8_t *)sound->m_words.get() + (size_t)wave.m_frames * fried_wave_sample_bytes(wave);
        std::fill(padding, (uint8_t *)(sound->m_words.get() + sound->m_wordCount), 0);
        sound->m_format = fried_wave_format(wave);
        sound->m_rate = wave.m_rate;
        sound->m_durationUs = (uint64_t)wave.m_frames * 1000000 / wave.m_rate;
        sound->m_volume = 1.0;

        // The sound hardware reads main RAM directly, past the ARM9's cache.
        DC_FlushRange(sound->m_words.get(), sound->m_wordCount * 4);
        return sound;
    }

    // A free channel, or else the one whose sound started longest ago.
    int channelFor(uint64_t now)
    {
        int oldest = 0;
        for (int index = 0; index < s_soundChannelCount; ++index)
        {
            if (s_channels[index].m_soundId < 0 || s_channels[index].m_endUs <= now)
            {
                return index;
            }
            if (s_channels[index].m_startUs < s_channels[oldest].m_startUs)
            {
                oldest = index;
            }
        }
        return oldest;
    }
}

void fried_sound_init()
{
    for (Channel &channel : s_channels)
    {
        channel = {-1, false, 0, 0};
    }
}

void fried_sound_update()
{
    uint64_t now = fried_audio_now_us();
    for (int index = 0; index < s_soundChannelCount; ++index)
    {
        Channel &channel = s_channels[index];
        if (channel.m_soundId < 0 || channel.m_endUs > now)
        {
            continue;
        }
        if (channel.m_repeats)
        {
            stopChannel(index);
        }
        else
        {
            channel.m_soundId = -1;
        }
    }
}

int fried_sound_load(const char *path)
{
    if (!path)
    {
        fried_set_last_error("No path given");
        return -1;
    }

    int fd = open(path, O_RDONLY);
    if (fd < 0)
    {
        fried_set_last_error("No such file");
        return -1;
    }
    Sound *sound = readSound(fd);
    close(fd);
    return s_sounds.store(sound);
}

void fried_sound_destroy(int soundId)
{
    fried_sound_stop(soundId);
    delete s_sounds.release(soundId);
}

// loops is how many times the sound plays again after the first, or -1 for
// ever. A sound that plays more than once loops in the hardware, and is
// stopped by fried_sound_update() once its last time through is over.
void fried_sound_play(int soundId, int loops)
{
    Sound *sound = s_sounds.get(soundId);
    if (!sound)
    {
        return;
    }
    uint64_t now = fried_audio_now_us();
    int index = channelFor(now);
    bool repeats = loops != 0;
    uint64_t end = loops < 0 ? s_forever : now + sound->m_durationUs * (uint64_t)(loops + 1);

    soundStop(1u << index);
    soundPreparePcm(index | SOUND_START, fried_audio_hardware_volume(sound->m_volume), s_centrePan,
                    soundTimerFromHz(sound->m_rate), repeats ? SoundMode_Repeat : SoundMode_OneShot,
                    sound->m_format, sound->m_words.get(), 0, sound->m_wordCount);
    s_channels[index] = {soundId, repeats, now, end};
}

void fried_sound_stop(int soundId)
{
    for (int index = 0; index < s_soundChannelCount; ++index)
    {
        if (s_channels[index].m_soundId == soundId && soundId >= 0)
        {
            stopChannel(index);
        }
    }
}

bool fried_sound_is_playing(int soundId)
{
    uint64_t now = fried_audio_now_us();
    for (const Channel &channel : s_channels)
    {
        if (channel.m_soundId == soundId && soundId >= 0 && channel.m_endUs > now)
        {
            return true;
        }
    }
    return false;
}

void fried_sound_set_volume(int soundId, double volume)
{
    Sound *sound = s_sounds.get(soundId);
    if (!sound)
    {
        return;
    }
    sound->m_volume = volume < 0.0 ? 0.0 : volume > 1.0 ? 1.0 : volume;

    uint64_t now = fried_audio_now_us();
    for (int index = 0; index < s_soundChannelCount; ++index)
    {
        if (s_channels[index].m_soundId == soundId && s_channels[index].m_endUs > now)
        {
            soundChSetVolume(index, fried_audio_hardware_volume(sound->m_volume));
        }
    }
}

double fried_sound_get_volume(int soundId)
{
    Sound *sound = s_sounds.get(soundId);
    return sound ? sound->m_volume : 0.0;
}
