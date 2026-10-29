#pragma once

#include <nds.h>

#include <cstdint>

// A PCM WAV, played as the DS's sound hardware plays it: one channel of
// signed 8 or 16 bit samples at the file's own rate.
struct FriedWave
{
    int m_channels;
    int m_bits;
    unsigned m_rate;
    uint32_t m_dataOffset;
    uint32_t m_frames;
};

// Reads the header of an open file, with the reason in the last error when
// it is not a WAV the DS plays.
bool fried_wave_read_header(int fd, FriedWave &wave);

inline int fried_wave_frame_bytes(const FriedWave &wave)
{
    return wave.m_bits / 8 * wave.m_channels;
}

inline int fried_wave_sample_bytes(const FriedWave &wave)
{
    return wave.m_bits / 8;
}

inline SoundFmt fried_wave_format(const FriedWave &wave)
{
    return wave.m_bits == 16 ? SoundFmt_Pcm16 : SoundFmt_Pcm8;
}

// Turns frames of the file's data into the hardware's samples, which may be
// written over the data itself, since they never take more room.
void fried_wave_convert(const FriedWave &wave, const uint8_t *data, uint32_t frames, void *samples);
