#include "audio/sound.h"
#include "audio/sound_nds.h"

#include "handle_pool.h"
#include "last_error.h"

#include <fcntl.h>
#include <sys/time.h>
#include <unistd.h>
#include <nds.h>

#include <cstdint>
#include <cstring>
#include <new>
#include <vector>

// A sound is a WAV read whole into main RAM as signed PCM, which the DS's
// sound hardware plays from there at the file's own rate, mixing the channels
// itself, so playing one costs the ARM9 nothing. The channels are told what
// to play through the ARM7, which reports back only now and then, so whether
// one is still playing is worked out here from when it started and how long
// it lasts. The last channel is the music's.

namespace
{
    constexpr int s_firstChannel = 0;
    constexpr int s_channelCount = 15;
    constexpr unsigned s_maxHardwareVolume = 2047;
    constexpr unsigned s_centrePan = 64;
    constexpr uint64_t s_forever = UINT64_MAX;

    struct Sound
    {
        std::vector<uint32_t> m_words;
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
    Channel s_channels[s_channelCount];

    uint64_t nowUs()
    {
        timeval now;
        gettimeofday(&now, nullptr);
        return (uint64_t)now.tv_sec * 1000000 + now.tv_usec;
    }

    unsigned hardwareVolume(double volume)
    {
        if (volume < 0.0)
        {
            volume = 0.0;
        }
        else if (volume > 1.0)
        {
            volume = 1.0;
        }
        return (unsigned)(volume * s_maxHardwareVolume + 0.5);
    }

    void stopChannel(int index)
    {
        soundStop(1u << (s_firstChannel + index));
        s_channels[index] = {-1, false, 0, 0};
    }

    // One read for the whole file, as the textures are read.
    unsigned char *readFile(const char *path, int &size)
    {
        int fd = open(path, O_RDONLY);
        if (fd < 0)
        {
            fried_set_last_error("No such file");
            return nullptr;
        }

        off_t end = lseek(fd, 0, SEEK_END);
        unsigned char *contents = end > 0 ? new (std::nothrow) unsigned char[end] : nullptr;
        bool read = contents && lseek(fd, 0, SEEK_SET) == 0 && ::read(fd, contents, end) == end;
        close(fd);

        if (!read)
        {
            delete[] contents;
            fried_set_last_error(end > 0 && !contents ? "Not enough memory to read the file" : "Failed to read the file");
            return nullptr;
        }
        size = (int)end;
        return contents;
    }

    uint16_t littleEndian16(const unsigned char *bytes)
    {
        return (uint16_t)(bytes[0] | (bytes[1] << 8));
    }

    uint32_t littleEndian32(const unsigned char *bytes)
    {
        return (uint32_t)(bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | ((uint32_t)bytes[3] << 24));
    }

    struct WaveFormat
    {
        int m_channels;
        int m_bits;
        unsigned m_rate;
        const unsigned char *m_data;
        uint32_t m_dataBytes;
    };

    // The fmt and data chunks of a RIFF WAVE, wherever they sit among the others.
    bool parseWave(const unsigned char *file, int size, WaveFormat &wave)
    {
        if (size < 12 || std::memcmp(file, "RIFF", 4) != 0 || std::memcmp(file + 8, "WAVE", 4) != 0)
        {
            fried_set_last_error("Not a WAV file, the only kind of sound the DS plays");
            return false;
        }

        bool hasFormat = false;
        wave.m_data = nullptr;
        for (int at = 12; at + 8 <= size;)
        {
            uint32_t chunkBytes = littleEndian32(file + at + 4);
            const unsigned char *chunk = file + at + 8;
            if (chunkBytes > (uint32_t)(size - at - 8))
            {
                chunkBytes = (uint32_t)(size - at - 8);
            }

            if (std::memcmp(file + at, "fmt ", 4) == 0 && chunkBytes >= 16)
            {
                uint16_t tag = littleEndian16(chunk);
                // WAVE_FORMAT_EXTENSIBLE names its encoding in the first two bytes of a GUID.
                if (tag == 0xFFFE && chunkBytes >= 26)
                {
                    tag = littleEndian16(chunk + 24);
                }
                if (tag != 1)
                {
                    fried_set_last_error("Only PCM WAV files play on the DS");
                    return false;
                }
                wave.m_channels = littleEndian16(chunk + 2);
                wave.m_rate = littleEndian32(chunk + 4);
                wave.m_bits = littleEndian16(chunk + 14);
                hasFormat = true;
            }
            else if (std::memcmp(file + at, "data", 4) == 0)
            {
                wave.m_data = chunk;
                wave.m_dataBytes = chunkBytes;
            }
            at += 8 + (int)((chunkBytes + 1) & ~1u);
        }

        if (!hasFormat || !wave.m_data)
        {
            fried_set_last_error("A WAV file with no fmt or data chunk");
            return false;
        }
        if ((wave.m_bits != 8 && wave.m_bits != 16) || wave.m_channels < 1 || wave.m_channels > 2 || wave.m_rate == 0)
        {
            fried_set_last_error("Only 8 or 16 bit WAV files of one or two channels play on the DS");
            return false;
        }
        return true;
    }

    // Each channel plays one stream, so a stereo file is mixed down to mono.
    // A WAV's 8 bit samples are unsigned, and the hardware's are signed.
    Sound *convert(const WaveFormat &wave)
    {
        int bytesPerSample = wave.m_bits / 8;
        uint32_t frames = wave.m_dataBytes / (bytesPerSample * wave.m_channels);
        if (frames == 0)
        {
            fried_set_last_error("A WAV file with no samples");
            return nullptr;
        }

        Sound *sound = new (std::nothrow) Sound;
        if (!sound)
        {
            fried_set_last_error("Not enough memory for the sound");
            return nullptr;
        }
        sound->m_format = wave.m_bits == 16 ? SoundFmt_Pcm16 : SoundFmt_Pcm8;
        sound->m_rate = wave.m_rate;
        sound->m_durationUs = (uint64_t)frames * 1000000 / wave.m_rate;
        sound->m_volume = 1.0;

        size_t bytes = (size_t)frames * bytesPerSample;
        sound->m_words.assign((bytes + 3) / 4, 0);
        const unsigned char *source = wave.m_data;
        if (wave.m_bits == 16)
        {
            int16_t *samples = (int16_t *)sound->m_words.data();
            for (uint32_t frame = 0; frame < frames; ++frame)
            {
                int sum = 0;
                for (int channel = 0; channel < wave.m_channels; ++channel, source += 2)
                {
                    sum += (int16_t)littleEndian16(source);
                }
                samples[frame] = (int16_t)(sum / wave.m_channels);
            }
        }
        else
        {
            int8_t *samples = (int8_t *)sound->m_words.data();
            for (uint32_t frame = 0; frame < frames; ++frame)
            {
                int sum = 0;
                for (int channel = 0; channel < wave.m_channels; ++channel, ++source)
                {
                    sum += *source - 128;
                }
                samples[frame] = (int8_t)(sum / wave.m_channels);
            }
        }

        // The sound hardware reads main RAM directly, past the ARM9's cache.
        DC_FlushRange(sound->m_words.data(), sound->m_words.size() * 4);
        return sound;
    }

    // A free channel, or else the one whose sound started longest ago.
    int channelFor(uint64_t now)
    {
        int oldest = 0;
        for (int index = 0; index < s_channelCount; ++index)
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
    uint64_t now = nowUs();
    for (int index = 0; index < s_channelCount; ++index)
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

    int size = 0;
    unsigned char *file = readFile(path, size);
    if (!file)
    {
        return -1;
    }

    WaveFormat wave = {};
    Sound *sound = parseWave(file, size, wave) ? convert(wave) : nullptr;
    delete[] file;
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
    uint64_t now = nowUs();
    int index = channelFor(now);
    bool repeats = loops != 0;
    uint64_t end = loops < 0 ? s_forever : now + sound->m_durationUs * (uint64_t)(loops + 1);

    soundStop(1u << (s_firstChannel + index));
    soundPreparePcm((s_firstChannel + index) | SOUND_START, hardwareVolume(sound->m_volume), s_centrePan,
                    soundTimerFromHz(sound->m_rate), repeats ? SoundMode_Repeat : SoundMode_OneShot,
                    sound->m_format, sound->m_words.data(), 0, (unsigned)sound->m_words.size());
    s_channels[index] = {soundId, repeats, now, end};
}

void fried_sound_stop(int soundId)
{
    for (int index = 0; index < s_channelCount; ++index)
    {
        if (s_channels[index].m_soundId == soundId && soundId >= 0)
        {
            stopChannel(index);
        }
    }
}

bool fried_sound_is_playing(int soundId)
{
    uint64_t now = nowUs();
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

    uint64_t now = nowUs();
    for (int index = 0; index < s_channelCount; ++index)
    {
        if (s_channels[index].m_soundId == soundId && s_channels[index].m_endUs > now)
        {
            soundChSetVolume(s_firstChannel + index, hardwareVolume(sound->m_volume));
        }
    }
}

double fried_sound_get_volume(int soundId)
{
    Sound *sound = s_sounds.get(soundId);
    return sound ? sound->m_volume : 0.0;
}
