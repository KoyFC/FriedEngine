#include "audio/music.h"

#include "audio/audio_nds.h"
#include "audio/wave_nds.h"
#include "handle_pool.h"
#include "last_error.h"

#include <fcntl.h>
#include <unistd.h>
#include <nds.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <new>

// A track is a WAV too large to hold in RAM, so it is read from its file a
// little ahead of where it plays. The music channel loops over a ring of
// samples in main RAM, and every frame the ring is refilled behind the point
// the channel has reached, which is worked out from the clock and the rate
// the channel's timer really runs at. A frame that stalls for longer than the
// ring lasts makes the channel play the ring around again, and the music
// carries on from where it was read up to. Only one track plays at a time,
// so the ring is allocated once, by the first one played, and kept.

namespace
{
    constexpr uint32_t s_ringSamples = 32768;
    // Kept unwritten ahead of the channel, for the time the ARM7 takes to start it.
    constexpr uint32_t s_ringMargin = s_ringSamples / 8;
    constexpr uint32_t s_readFrames = 1024;
    constexpr uint64_t s_noEnd = UINT64_MAX;

    struct Music
    {
        int m_fd;
        FriedWave m_wave;
    };

    // Positions count samples since the track was started, and the sample at
    // m_origin is the one at the start of the ring when the channel started.
    // m_startUs is 0 until the channel has been started.
    struct Stream
    {
        int m_musicId;
        bool m_paused;
        int m_playsLeft;
        unsigned m_timer;
        uint64_t m_startUs;
        uint64_t m_origin;
        uint64_t m_written;
        uint64_t m_end;
        uint64_t m_pausedAt;
        uint32_t m_nextFrame;
    };

    HandlePool<Music> s_music;
    Stream s_stream = {-1, false, 0, 0, 0, 0, 0, s_noEnd, 0, 0};
    uint8_t *s_ring = nullptr;
    uint8_t *s_readBuffer = nullptr;
    double s_volume = 1.0;

    Music *streamed()
    {
        return s_stream.m_musicId >= 0 ? s_music.get(s_stream.m_musicId) : nullptr;
    }

    bool isOnStream(int musicId)
    {
        return musicId >= 0 && musicId == s_stream.m_musicId;
    }

    uint32_t ringBytes(const FriedWave &wave)
    {
        return s_ringSamples * fried_wave_sample_bytes(wave);
    }

    uint32_t ringIndex(uint64_t sample)
    {
        return (uint32_t)((sample - s_stream.m_origin) % s_ringSamples);
    }

    // The sound clock is the system clock halved, and the channel's timer
    // divides it, so this is exact where the file's rate would drift.
    uint64_t playedAt(uint64_t now)
    {
        if (s_stream.m_startUs == 0)
        {
            return s_stream.m_origin;
        }
        uint64_t elapsed = now - s_stream.m_startUs;
        return s_stream.m_origin + elapsed * SOUND_CLOCK / ((uint64_t)s_stream.m_timer * 1000000);
    }

    void startChannel(const Music &music)
    {
        soundPreparePcm(s_musicChannel | SOUND_START, fried_audio_hardware_volume(s_volume), s_centrePan,
                        s_stream.m_timer, SoundMode_Repeat, fried_wave_format(music.m_wave), s_ring, 0,
                        ringBytes(music.m_wave) / 4);
        s_stream.m_startUs = fried_audio_now_us();
    }

    void stopStream()
    {
        soundStop(1u << s_musicChannel);
        s_stream.m_musicId = -1;
        s_stream.m_paused = false;
    }

    // Reads the track into the ring up to the sample given, starting it over
    // as many times as it is played and writing silence once it has ended.
    void fill(Music &music, uint64_t upTo)
    {
        const FriedWave &wave = music.m_wave;
        int frameBytes = fried_wave_frame_bytes(wave);
        int sampleBytes = fried_wave_sample_bytes(wave);
        while (s_stream.m_written < upTo)
        {
            uint32_t index = ringIndex(s_stream.m_written);
            uint32_t count = (uint32_t)std::min<uint64_t>(upTo - s_stream.m_written, s_ringSamples - index);
            uint8_t *destination = s_ring + index * sampleBytes;

            if (s_stream.m_end == s_noEnd && s_stream.m_nextFrame >= wave.m_frames)
            {
                if (s_stream.m_playsLeft != 1)
                {
                    s_stream.m_playsLeft = s_stream.m_playsLeft < 0 ? -1 : s_stream.m_playsLeft - 1;
                    s_stream.m_nextFrame = 0;
                    lseek(music.m_fd, wave.m_dataOffset, SEEK_SET);
                }
                else
                {
                    s_stream.m_end = s_stream.m_written;
                }
            }

            if (s_stream.m_end != s_noEnd)
            {
                std::memset(destination, 0, count * sampleBytes);
            }
            else
            {
                count = std::min({count, s_readFrames, wave.m_frames - s_stream.m_nextFrame});
                ssize_t read = ::read(music.m_fd, s_readBuffer, count * frameBytes);
                uint32_t frames = read > 0 ? (uint32_t)read / frameBytes : 0;
                if (frames == 0)
                {
                    // A file that can no longer be read ends the track there.
                    s_stream.m_end = s_stream.m_written;
                    continue;
                }
                count = frames;
                fried_wave_convert(wave, s_readBuffer, count, destination);
                s_stream.m_nextFrame += count;
            }

            // The sound hardware reads main RAM directly, past the ARM9's cache.
            DC_FlushRange(destination, count * sampleBytes);
            s_stream.m_written += count;
        }
    }

    bool allocateBuffers()
    {
        if (!s_ring)
        {
            s_ring = new (std::nothrow) uint8_t[s_ringSamples * 2];
        }
        if (!s_readBuffer)
        {
            s_readBuffer = new (std::nothrow) uint8_t[s_readFrames * 4];
        }
        return s_ring && s_readBuffer;
    }
}


void fried_music_update()
{

    Music *music = streamed();
    if (!music || s_stream.m_paused)
    {
        return;
    }
    // Started here rather than when it is played, since a game often plays
    // its music before a first frame that takes longer than the ring lasts.
    if (s_stream.m_startUs == 0)
    {
        startChannel(*music);
        return;
    }

    uint64_t played = playedAt(fried_audio_now_us());
    if (played >= s_stream.m_end)
    {
        stopStream();
        return;
    }
    if (played > s_stream.m_written)
    {
        s_stream.m_written = played;
    }
    fill(*music, played + s_ringSamples - s_ringMargin);
}

int fried_music_load(const char *path)
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

    Music *music = new (std::nothrow) Music{fd, {}};
    if (!music || !fried_wave_read_header(fd, music->m_wave))
    {
        if (!music)
        {
            fried_set_last_error("Not enough memory for the music");
        }
        delete music;
        close(fd);
        return -1;
    }
    return s_music.store(music);
}

void fried_music_destroy(int musicId)
{
    fried_music_stop(musicId);
    Music *music = s_music.release(musicId);
    if (music)
    {
        close(music->m_fd);
        delete music;
    }
}

// loops is how many times the track plays, once for 0 as for 1, or -1 for ever.
void fried_music_play(int musicId, int loops)
{
    Music *music = s_music.get(musicId);
    if (!music)
    {
        return;
    }
    if (!allocateBuffers())
    {
        fried_set_last_error("Not enough memory to stream the music");
        return;
    }
    if (streamed())
    {
        stopStream();
    }

    s_stream = {musicId, false, loops < 0 ? -1 : std::max(loops, 1), soundTimerFromHz(music->m_wave.m_rate),
                0, 0, 0, s_noEnd, 0, 0};
    lseek(music->m_fd, music->m_wave.m_dataOffset, SEEK_SET);
    fill(*music, s_ringSamples - s_ringMargin);
}

void fried_music_pause(int musicId)
{
    if (!isOnStream(musicId) || s_stream.m_paused)
    {
        return;
    }
    soundStop(1u << s_musicChannel);
    s_stream.m_pausedAt = std::min(playedAt(fried_audio_now_us()), s_stream.m_written);
    s_stream.m_paused = true;
}

// The channel starts again at the start of the ring, so the ring is turned
// until the sample it was paused on is there.
void fried_music_resume(int musicId)
{
    Music *music = streamed();
    if (!isOnStream(musicId) || !s_stream.m_paused || !music)
    {
        return;
    }
    uint32_t sampleBytes = fried_wave_sample_bytes(music->m_wave);
    std::rotate(s_ring, s_ring + ringIndex(s_stream.m_pausedAt) * sampleBytes, s_ring + ringBytes(music->m_wave));
    s_stream.m_origin = s_stream.m_pausedAt;
    s_stream.m_paused = false;
    DC_FlushRange(s_ring, ringBytes(music->m_wave));
    startChannel(*music);
}

void fried_music_stop(int musicId)
{
    if (isOnStream(musicId))
    {
        stopStream();
    }
}

bool fried_music_is_playing(int musicId)
{
    return isOnStream(musicId) && !s_stream.m_paused && playedAt(fried_audio_now_us()) < s_stream.m_end;
}

bool fried_music_is_paused(int musicId)
{
    return isOnStream(musicId) && s_stream.m_paused;
}

void fried_music_set_volume(double volume)
{
    s_volume = volume < 0.0 ? 0.0 : volume > 1.0 ? 1.0 : volume;
    if (streamed() && !s_stream.m_paused)
    {
        soundChSetVolume(s_musicChannel, fried_audio_hardware_volume(s_volume));
    }
}

double fried_music_get_volume()
{
    return s_volume;
}
