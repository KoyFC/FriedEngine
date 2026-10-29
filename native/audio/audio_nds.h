#pragma once

#include <sys/time.h>

#include <cstdint>

// Channels 0 to 14 play sounds and channel 15 the music.
constexpr int s_soundChannelCount = 15;
constexpr int s_musicChannel = 15;

constexpr unsigned s_maxHardwareVolume = 2047;
constexpr unsigned s_centrePan = 64;

inline unsigned fried_audio_hardware_volume(double volume)
{
    volume = volume < 0.0 ? 0.0 : volume > 1.0 ? 1.0 : volume;
    return (unsigned)(volume * s_maxHardwareVolume + 0.5);
}

// The ARM7 says what the channels are playing only now and then, so where
// they are is worked out from the clock.
inline uint64_t fried_audio_now_us()
{
    timeval now;
    gettimeofday(&now, nullptr);
    return (uint64_t)now.tv_sec * 1000000 + now.tv_usec;
}

// Called once the sound hardware is on, before any sound plays.
void fried_sound_init();

// Called every frame: stops a sound that loops a set number of times once it
// has played them all, and reads the music ahead of where it plays.
void fried_sound_update();
void fried_music_update();
