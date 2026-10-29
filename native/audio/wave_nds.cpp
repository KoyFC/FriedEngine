#include "audio/wave_nds.h"

#include "last_error.h"

#include <unistd.h>

#include <cstring>

namespace
{
    uint16_t littleEndian16(const uint8_t *bytes)
    {
        return (uint16_t)(bytes[0] | (bytes[1] << 8));
    }

    uint32_t littleEndian32(const uint8_t *bytes)
    {
        return (uint32_t)(bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | ((uint32_t)bytes[3] << 24));
    }

    bool readAt(int fd, off_t offset, void *buffer, size_t bytes)
    {
        return lseek(fd, offset, SEEK_SET) == offset && read(fd, buffer, bytes) == (ssize_t)bytes;
    }
}

// The fmt and data chunks of a RIFF WAVE, wherever they sit among the others.
bool fried_wave_read_header(int fd, FriedWave &wave)
{
    off_t size = lseek(fd, 0, SEEK_END);
    uint8_t riff[12];
    if (size < 12 || !readAt(fd, 0, riff, sizeof(riff)) || std::memcmp(riff, "RIFF", 4) != 0 ||
        std::memcmp(riff + 8, "WAVE", 4) != 0)
    {
        fried_set_last_error("Not a WAV file, the only kind of sound the DS plays");
        return false;
    }

    bool hasFormat = false, hasData = false;
    uint32_t dataBytes = 0;
    for (off_t at = 12; at + 8 <= size;)
    {
        uint8_t header[8];
        if (!readAt(fd, at, header, sizeof(header)))
        {
            break;
        }
        uint32_t chunkBytes = littleEndian32(header + 4);
        if (chunkBytes > (uint32_t)(size - at - 8))
        {
            chunkBytes = (uint32_t)(size - at - 8);
        }

        uint8_t format[26] = {};
        if (std::memcmp(header, "fmt ", 4) == 0 && chunkBytes >= 16 &&
            readAt(fd, at + 8, format, chunkBytes < sizeof(format) ? chunkBytes : sizeof(format)))
        {
            uint16_t tag = littleEndian16(format);
            // WAVE_FORMAT_EXTENSIBLE names its encoding in the first two bytes of a GUID.
            if (tag == 0xFFFE && chunkBytes >= 26)
            {
                tag = littleEndian16(format + 24);
            }
            if (tag != 1)
            {
                fried_set_last_error("Only PCM WAV files play on the DS");
                return false;
            }
            wave.m_channels = littleEndian16(format + 2);
            wave.m_rate = littleEndian32(format + 4);
            wave.m_bits = littleEndian16(format + 14);
            hasFormat = true;
        }
        else if (std::memcmp(header, "data", 4) == 0)
        {
            wave.m_dataOffset = (uint32_t)(at + 8);
            dataBytes = chunkBytes;
            hasData = true;
        }
        at += 8 + (off_t)((chunkBytes + 1) & ~1u);
    }

    if (!hasFormat || !hasData)
    {
        fried_set_last_error("A WAV file with no fmt or data chunk");
        return false;
    }
    if ((wave.m_bits != 8 && wave.m_bits != 16) || wave.m_channels < 1 || wave.m_channels > 2 || wave.m_rate == 0)
    {
        fried_set_last_error("Only 8 or 16 bit WAV files of one or two channels play on the DS");
        return false;
    }
    wave.m_frames = dataBytes / fried_wave_frame_bytes(wave);
    if (wave.m_frames == 0)
    {
        fried_set_last_error("A WAV file with no samples");
        return false;
    }
    return true;
}

// Each channel plays one stream, so a stereo file is mixed down to mono.
// A WAV's 8 bit samples are unsigned, and the hardware's are signed.
void fried_wave_convert(const FriedWave &wave, const uint8_t *data, uint32_t frames, void *samples)
{
    if (wave.m_bits == 16)
    {
        int16_t *output = (int16_t *)samples;
        for (uint32_t frame = 0; frame < frames; ++frame)
        {
            int sum = 0;
            for (int channel = 0; channel < wave.m_channels; ++channel, data += 2)
            {
                sum += (int16_t)littleEndian16(data);
            }
            output[frame] = (int16_t)(sum / wave.m_channels);
        }
        return;
    }

    int8_t *output = (int8_t *)samples;
    for (uint32_t frame = 0; frame < frames; ++frame)
    {
        int sum = 0;
        for (int channel = 0; channel < wave.m_channels; ++channel, ++data)
        {
            sum += *data - 128;
        }
        output[frame] = (int8_t)(sum / wave.m_channels);
    }
}
