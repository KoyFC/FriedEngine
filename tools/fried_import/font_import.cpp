#include "font_import.h"

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <map>

namespace fried_import
{
    namespace
    {
        uint32_t readU32(const unsigned char *at)
        {
            return ((uint32_t)at[0] << 24) | ((uint32_t)at[1] << 16) | ((uint32_t)at[2] << 8) | at[3];
        }

        uint16_t readU16(const unsigned char *at)
        {
            return (uint16_t)((at[0] << 8) | at[1]);
        }

        void writeU32(unsigned char *at, uint32_t value)
        {
            at[0] = (unsigned char)(value >> 24);
            at[1] = (unsigned char)(value >> 16);
            at[2] = (unsigned char)(value >> 8);
            at[3] = (unsigned char)value;
        }

        void appendU32(std::vector<unsigned char> &bytes, uint32_t value)
        {
            bytes.resize(bytes.size() + 4);
            writeU32(&bytes[bytes.size() - 4], value);
        }

        void appendU16(std::vector<unsigned char> &bytes, uint16_t value)
        {
            bytes.push_back((unsigned char)(value >> 8));
            bytes.push_back((unsigned char)value);
        }

        uint32_t checksum(const unsigned char *data, size_t length)
        {
            uint32_t sum = 0;
            for (size_t index = 0; index < length; index += 4)
            {
                unsigned char word[4] = {0, 0, 0, 0};
                std::memcpy(word, data + index, std::min<size_t>(4, length - index));
                sum += readU32(word);
            }
            return sum;
        }

        bool isDropped(const char *tag)
        {
            static const char *const dropped[] = {"gvar", "HVAR", "MVAR", "STAT", "fvar", "avar", "GSUB", "GDEF"};
            for (const char *name : dropped)
            {
                if (std::memcmp(tag, name, 4) == 0)
                {
                    return true;
                }
            }
            return false;
        }
    }

    bool stripFontTables(const std::vector<unsigned char> &file, std::vector<unsigned char> *out, std::string *error)
    {
        if (file.size() < 12 || readU32(file.data()) != 0x00010000)
        {
            *error = "is not a single TrueType font";
            return false;
        }
        int count = readU16(file.data() + 4);
        if (file.size() < (size_t)(12 + 16 * count))
        {
            *error = "has a table directory that does not fit in the file";
            return false;
        }

        std::map<std::string, std::vector<unsigned char>> tables;
        for (int index = 0; index < count; ++index)
        {
            const unsigned char *entry = file.data() + 12 + 16 * index;
            uint32_t offset = readU32(entry + 8);
            uint32_t length = readU32(entry + 12);
            if ((size_t)offset + length > file.size())
            {
                *error = "has a table that runs past the end of the file";
                return false;
            }
            if (!isDropped((const char *)entry))
            {
                tables[std::string((const char *)entry, 4)].assign(file.begin() + offset, file.begin() + offset + length);
            }
        }
        auto head = tables.find("head");
        if (head == tables.end() || head->second.size() < 54)
        {
            *error = "has no head table";
            return false;
        }
        std::memset(&head->second[8], 0, 4);

        int entries = (int)tables.size();
        int power = 1;
        int exponent = 0;
        while (power * 2 <= entries)
        {
            power *= 2;
            ++exponent;
        }

        std::vector<unsigned char> font(file.begin(), file.begin() + 4);
        appendU16(font, (uint16_t)entries);
        appendU16(font, (uint16_t)(power * 16));
        appendU16(font, (uint16_t)exponent);
        appendU16(font, (uint16_t)(entries * 16 - power * 16));

        uint32_t offset = 12 + 16 * entries;
        for (const auto &table : tables)
        {
            font.insert(font.end(), table.first.begin(), table.first.end());
            appendU32(font, checksum(table.second.data(), table.second.size()));
            appendU32(font, offset);
            appendU32(font, (uint32_t)table.second.size());
            offset += (uint32_t)((table.second.size() + 3) & ~(size_t)3);
        }
        size_t headAt = 0;
        for (const auto &table : tables)
        {
            if (table.first == "head")
            {
                headAt = font.size();
            }
            font.insert(font.end(), table.second.begin(), table.second.end());
            font.resize((font.size() + 3) & ~(size_t)3, 0);
        }
        writeU32(&font[headAt + 8], 0xB1B0AFBAu - checksum(font.data(), font.size()));
        *out = std::move(font);
        return true;
    }
}
