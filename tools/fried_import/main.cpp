// fried_import --platform <pc|vita|switch|3ds|nds|cg50|web> --in <assets> --out <imported>
//
// Writes the assets of a folder into another as a platform wants them. A file
// with a sidecar, "sprite.png.import", is converted as the sidecar says for
// that platform, and every other file is copied. Sidecars are not copied. A
// file that is already as new as what it comes from is left alone, and
// whatever is left in the destination that no longer comes from anything is
// removed.
#include "audio_import.h"
#include "image_import.h"
#include "import_settings.h"

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <set>
#include <sstream>

namespace fs = std::filesystem;

namespace
{
    std::string lowerExtension(const fs::path &path)
    {
        std::string extension = path.extension().string();
        std::transform(extension.begin(), extension.end(), extension.begin(), [](unsigned char c) { return (char)std::tolower(c); });
        return extension;
    }

    bool readFile(const fs::path &path, std::vector<unsigned char> *bytes)
    {
        std::ifstream stream(path, std::ios::binary);
        if (!stream)
        {
            return false;
        }
        bytes->assign(std::istreambuf_iterator<char>(stream), std::istreambuf_iterator<char>());
        return true;
    }

    bool writeFile(const fs::path &path, const std::vector<unsigned char> &bytes)
    {
        fs::create_directories(path.parent_path());
        std::ofstream stream(path, std::ios::binary | std::ios::trunc);
        stream.write((const char *)bytes.data(), (std::streamsize)bytes.size());
        return (bool)stream;
    }

    bool isUpToDate(const fs::path &destination, const fs::path &source, const fs::path &sidecar)
    {
        std::error_code ignored;
        if (!fs::exists(destination, ignored))
        {
            return false;
        }
        fs::file_time_type built = fs::last_write_time(destination, ignored);
        if (built < fs::last_write_time(source, ignored))
        {
            return false;
        }
        return sidecar.empty() || built >= fs::last_write_time(sidecar, ignored);
    }
}

int main(int argc, char **argv)
{
    std::string platform, input, output;
    for (int index = 1; index + 1 < argc; index += 2)
    {
        std::string flag = argv[index];
        (flag == "--platform" ? platform : flag == "--in" ? input : flag == "--out" ? output : flag) = argv[index + 1];
    }
    if (platform.empty() || input.empty() || output.empty())
    {
        std::cerr << "usage: fried_import --platform <platform> --in <assets> --out <imported>\n";
        return 2;
    }

    std::set<fs::path> expected;
    int failures = 0;
    std::error_code error;
    for (const fs::directory_entry &entry : fs::recursive_directory_iterator(input, error))
    {
        if (!entry.is_regular_file() || lowerExtension(entry.path()) == ".import")
        {
            continue;
        }
        fs::path relative = fs::relative(entry.path(), input);
        fs::path destination = fs::path(output) / relative;
        expected.insert(destination.lexically_normal());

        fs::path sidecar = entry.path();
        sidecar += ".import";
        bool hasSidecar = fs::exists(sidecar);
        if (isUpToDate(destination, entry.path(), hasSidecar ? sidecar : fs::path()))
        {
            continue;
        }

        fried_import::Settings settings;
        std::string message;
        if (hasSidecar)
        {
            std::ifstream stream(sidecar);
            std::stringstream text;
            text << stream.rdbuf();
            if (!fried_import::parseSettings(text.str(), platform, &settings, &message))
            {
                std::cerr << "fried_import: " << sidecar.string() << ": " << message << ", copied as it is\n";
                settings = fried_import::Settings();
            }
        }

        std::vector<unsigned char> source, converted;
        if (!readFile(entry.path(), &source))
        {
            std::cerr << "fried_import: cannot read " << entry.path().string() << "\n";
            ++failures;
            continue;
        }
        std::string extension = lowerExtension(entry.path());
        const std::vector<unsigned char> *result = &source;
        std::string warning;
        if (extension == ".png" && settings.m_hasImage && fried_import::changesImage(settings.m_image))
        {
            if (fried_import::convertImage(source, settings.m_image, &converted, &warning, &message))
            {
                result = &converted;
            }
            else
            {
                std::cerr << "fried_import: " << relative.string() << ": " << message << ", copied as it is\n";
            }
        }
        else if (extension == ".wav" && settings.m_hasAudio && fried_import::changesAudio(settings.m_audio))
        {
            if (fried_import::convertWav(source, settings.m_audio, &converted, &message))
            {
                result = &converted;
            }
            else
            {
                std::cerr << "fried_import: " << relative.string() << ": " << message << ", copied as it is\n";
            }
        }
        else if (hasSidecar && ((settings.m_hasImage && extension != ".png") || (settings.m_hasAudio && extension != ".wav")))
        {
            warning = "has settings that only apply to PNG images and WAV sounds, so it is copied as it is";
        }
        if (!warning.empty())
        {
            std::cerr << "fried_import: " << relative.string() << " " << warning << "\n";
        }
        if (!writeFile(destination, *result))
        {
            std::cerr << "fried_import: cannot write " << destination.string() << "\n";
            ++failures;
        }
    }

    if (fs::exists(output))
    {
        std::vector<fs::path> stale;
        for (const fs::directory_entry &entry : fs::recursive_directory_iterator(output))
        {
            if (entry.is_regular_file() && !expected.count(entry.path().lexically_normal()))
            {
                stale.push_back(entry.path());
            }
        }
        for (const fs::path &path : stale)
        {
            fs::remove(path);
        }
    }
    return failures == 0 ? 0 : 1;
}
