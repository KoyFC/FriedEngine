#include "audio_import.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>

namespace fried_import
{
    namespace
    {
        uint32_t read32(const unsigned char *at)
        {
            return at[0] | (at[1] << 8) | (at[2] << 16) | ((uint32_t)at[3] << 24);
        }

        uint16_t read16(const unsigned char *at)
        {
            return (uint16_t)(at[0] | (at[1] << 8));
        }

        void write32(std::vector<unsigned char> &bytes, uint32_t value)
        {
            for (int shift = 0; shift < 32; shift += 8)
            {
                bytes.push_back((unsigned char)(value >> shift));
            }
        }

        void write16(std::vector<unsigned char> &bytes, uint16_t value)
        {
            bytes.push_back((unsigned char)value);
            bytes.push_back((unsigned char)(value >> 8));
        }
    }

    bool changesAudio(const AudioSettings &settings)
    {
        return settings.m_mono || settings.m_sampleRate > 0 || settings.m_bits > 0;
    }

    bool convertWav(const std::vector<unsigned char> &file, const AudioSettings &settings, std::vector<unsigned char> *out, std::string *error)
    {
        if (file.size() < 12 || std::memcmp(file.data(), "RIFF", 4) != 0 || std::memcmp(file.data() + 8, "WAVE", 4) != 0)
        {
            *error = "not a WAV file";
            return false;
        }
        int channels = 0, rate = 0, bits = 0, format = 0;
        const unsigned char *data = nullptr;
        size_t dataSize = 0;
        size_t at = 12;
        while (at + 8 <= file.size())
        {
            size_t size = read32(&file[at + 4]);
            const unsigned char *body = &file[at + 8];
            if (at + 8 + size > file.size())
            {
                size = file.size() - at - 8;
            }
            if (std::memcmp(&file[at], "fmt ", 4) == 0 && size >= 16)
            {
                format = read16(body);
                channels = read16(body + 2);
                rate = (int)read32(body + 4);
                bits = read16(body + 14);
            }
            else if (std::memcmp(&file[at], "data", 4) == 0)
            {
                data = body;
                dataSize = size;
            }
            at += 8 + size + (size & 1);
        }
        if (format != 1 || (bits != 8 && bits != 16) || channels < 1 || rate <= 0 || !data)
        {
            *error = "only PCM WAV files of 8 or 16 bits are converted";
            return false;
        }

        size_t frames = dataSize / (size_t)(channels * bits / 8);
        std::vector<std::vector<float>> source((size_t)channels, std::vector<float>(frames));
        for (size_t frame = 0; frame < frames; ++frame)
        {
            for (int channel = 0; channel < channels; ++channel)
            {
                const unsigned char *sample = data + (frame * channels + channel) * (bits / 8);
                source[channel][frame] = bits == 8 ? (sample[0] - 128) / 128.0f : (int16_t)read16(sample) / 32768.0f;
            }
        }

        int outChannels = settings.m_mono ? 1 : channels;
        int outRate = settings.m_sampleRate > 0 ? settings.m_sampleRate : rate;
        int outBits = settings.m_bits > 0 ? settings.m_bits : bits;
        if (outBits != 8 && outBits != 16)
        {
            *error = "bits must be 8 or 16";
            return false;
        }
        size_t outFrames = rate == outRate ? frames : (size_t)((double)frames * outRate / rate);

        std::vector<unsigned char> samples;
        samples.reserve(outFrames * outChannels * (outBits / 8));
        for (size_t frame = 0; frame < outFrames; ++frame)
        {
            double position = rate == outRate ? (double)frame : (double)frame * rate / outRate;
            size_t first = std::min((size_t)position, frames - 1);
            size_t second = std::min(first + 1, frames - 1);
            float fraction = (float)(position - (double)first);
            auto at = [&](int channel) { return source[channel][first] * (1 - fraction) + source[channel][second] * fraction; };
            for (int channel = 0; channel < outChannels; ++channel)
            {
                float value = 0;
                if (settings.m_mono)
                {
                    for (int mixed = 0; mixed < channels; ++mixed)
                    {
                        value += at(mixed);
                    }
                    value /= (float)channels;
                }
                else
                {
                    value = at(channel);
                }
                value = std::clamp(value, -1.0f, 1.0f);
                if (outBits == 8)
                {
                    samples.push_back((unsigned char)std::lround(value * 127.0f + 128.0f));
                }
                else
                {
                    write16(samples, (uint16_t)(int16_t)std::lround(value * 32767.0f));
                }
            }
        }

        out->clear();
        out->insert(out->end(), {'R', 'I', 'F', 'F'});
        write32(*out, (uint32_t)(36 + samples.size()));
        out->insert(out->end(), {'W', 'A', 'V', 'E', 'f', 'm', 't', ' '});
        write32(*out, 16);
        write16(*out, 1);
        write16(*out, (uint16_t)outChannels);
        write32(*out, (uint32_t)outRate);
        write32(*out, (uint32_t)(outRate * outChannels * outBits / 8));
        write16(*out, (uint16_t)(outChannels * outBits / 8));
        write16(*out, (uint16_t)outBits);
        out->insert(out->end(), {'d', 'a', 't', 'a'});
        write32(*out, (uint32_t)samples.size());
        out->insert(out->end(), samples.begin(), samples.end());
        return true;
    }
}
