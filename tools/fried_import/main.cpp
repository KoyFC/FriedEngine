// fried_import --platform <pc|vita|switch|3ds|nds|cg50|web|android> --in <assets> --out <imported>
//
// Writes the assets of a folder into another as a platform wants them. A file
// with a sidecar, "sprite.png.import", is converted as the sidecar says for
// that platform, and every other file is copied. Sidecars are not copied. A
// file that is already as new as what it comes from is left alone, and
// whatever is left in the destination that no longer comes from anything is
// removed.
#include "audio_import.h"
#include "font_import.h"
#include "image_import.h"
#include "import_settings.h"
#include "yaml.h"
#include "model/model_convert.h"

#include <algorithm>
#include <cctype>
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
    // The platforms that rasterize text themselves with stb_truetype, which reads a whole font file into RAM and nothing from a font's variation or substitution tables.
    bool usesSoftwareText(const std::string &platform)
    {
        return platform == "nds" || platform == "cg50";
    }

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

    bool isModel(const std::string &extension)
    {
        return extension == ".obj" || extension == ".gltf" || extension == ".glb";
    }

    void warnAboutModelSize(const std::string &platform, const fs::path &relative, const fried_model::Result &model)
    {
        if (platform == "nds" && (model.m_triangleCount > 2048 || model.m_vertexCount > 6144))
        {
            std::cerr << "fried_import: " << relative.string() << " has " << model.m_triangleCount << " triangles and " << model.m_vertexCount
                      << " vertices, and the DS draws 2048 polygons and 6144 vertices in a frame\n";
        }
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

bool sameValue(const fried_import::Value &a, const fried_import::Value &b)
{
    using Kind = fried_import::Value::Kind;
    if (a.m_kind != b.m_kind)
    {
        return false;
    }
    switch (a.m_kind)
    {
    case Kind::Null: return true;
    case Kind::Bool: return a.m_bool == b.m_bool;
    case Kind::Number: return a.m_number == b.m_number && a.m_isInteger == b.m_isInteger;
    case Kind::String: return a.m_string == b.m_string;
    case Kind::Array:
        if (a.m_array.size() != b.m_array.size())
        {
            return false;
        }
        for (size_t i = 0; i < a.m_array.size(); ++i)
        {
            if (!sameValue(a.m_array[i], b.m_array[i]))
            {
                return false;
            }
        }
        return true;
    case Kind::Object:
        if (a.m_object.size() != b.m_object.size())
        {
            return false;
        }
        for (const auto &pair : a.m_object)
        {
            const fried_import::Value *other = b.find(pair.first);
            if (!other || !sameValue(pair.second, *other))
            {
                return false;
            }
        }
        return true;
    }
    return false;
}

std::string trimmed(std::string text)
{
    while (!text.empty() && std::isspace((unsigned char)text.back()))
    {
        text.pop_back();
    }
    return text;
}

std::string readText(const fs::path &path)
{
    std::ifstream stream(path, std::ios::binary);
    std::stringstream text;
    text << stream.rdbuf();
    return text.str();
}

// A case is name.yaml with the value it must give in name.json, or error-name.yaml with the message in error-name.txt.
int runCheckYaml(const std::string &directory)
{
    int failures = 0, checked = 0;
    std::vector<fs::path> files;
    for (const fs::directory_entry &entry : fs::directory_iterator(directory))
    {
        if (entry.path().extension() == ".yaml")
        {
            files.push_back(entry.path());
        }
    }
    std::sort(files.begin(), files.end());
    for (const fs::path &file : files)
    {
        ++checked;
        std::string name = file.stem().string();
        fried_import::Value parsed;
        std::string error;
        bool parsedOk = fried_import::parseYaml(readText(file), &parsed, &error);
        if (name.rfind("error-", 0) == 0)
        {
            fs::path expected = file;
            expected.replace_extension(".txt");
            if (parsedOk || error != trimmed(readText(expected)))
            {
                std::cerr << "FAIL " << name << ": expected the error \"" << trimmed(readText(expected)) << "\", got " << (parsedOk ? "a value" : "\"" + error + "\"") << "\n";
                ++failures;
            }
            continue;
        }
        fs::path expected = file;
        expected.replace_extension(".json");
        fried_import::Value wanted;
        std::string expectedError;
        if (!fried_import::parseYaml(readText(expected), &wanted, &expectedError))
        {
            std::cerr << "FAIL " << name << ": the expected JSON is wrong: " << expectedError << "\n";
            ++failures;
        }
        else if (!parsedOk || !sameValue(parsed, wanted))
        {
            std::cerr << "FAIL " << name << ": " << (parsedOk ? "the value differs from the JSON" : error) << "\n";
            ++failures;
        }
    }
    std::cerr << checked << " YAML cases, " << failures << " failed\n";
    return failures == 0 ? 0 : 1;
}

int runProjectJson(const std::string &input, const std::string &output)
{
    fried_import::Value value;
    std::string error;
    if (!fried_import::parseYaml(readText(input), &value, &error))
    {
        std::cerr << input << ":" << error << "\n";
        return 1;
    }
    if (value.m_kind != fried_import::Value::Kind::Object)
    {
        std::cerr << input << " must hold a map of keys and values\n";
        return 1;
    }
    std::string json = fried_import::toJson(value);
    std::vector<unsigned char> bytes(json.begin(), json.end());
    return writeFile(output, bytes) ? 0 : 1;
}

int main(int argc, char **argv)
{
    if (argc == 3 && std::string(argv[1]) == "--check-yaml")
    {
        return runCheckYaml(argv[2]);
    }
    if (argc == 4 && std::string(argv[1]) == "--project-json")
    {
        return runProjectJson(argv[2], argv[3]);
    }
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
        std::string extension = lowerExtension(entry.path());
        // A model depends on more files than itself, so it is read each time and only written when it changed.
        if (!isModel(extension) && isUpToDate(destination, entry.path(), hasSidecar ? sidecar : fs::path()))
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
        const std::vector<unsigned char> *result = &source;
        std::string warning;
        if (isModel(extension))
        {
            fried_model::Options options;
            options.m_stripImages = platform == "cg50";
            options.m_extract = [&](const std::vector<unsigned char> &png, const std::string &name) {
                std::string safe = name;
                std::replace_if(safe.begin(), safe.end(), [](unsigned char c) { return !std::isalnum(c) && c != '-' && c != '_'; }, '_');
                fs::path image = destination;
                image += "." + safe + ".png";
                expected.insert(image.lexically_normal());
                if (!writeFile(image, png))
                {
                    return std::string();
                }
                return image.filename().string();
            };
            fried_model::Result model;
            if (fried_model::convert(entry.path().string(), options, &model, &message))
            {
                converted = model.m_bytes;
                result = &converted;
                for (const std::string &text : model.m_warnings)
                {
                    std::cerr << "fried_import: " << relative.string() << ": " << text << "\n";
                }
                warnAboutModelSize(platform, relative, model);
                std::vector<unsigned char> existing;
                if (readFile(destination, &existing) && existing == converted)
                {
                    continue;
                }
            }
            else
            {
                std::cerr << "fried_import: " << relative.string() << ": " << message << ", copied as it is\n";
            }
        }
        else if (extension == ".png" && settings.m_hasImage && fried_import::changesImage(settings.m_image))
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
        else if (extension == ".ttf" && usesSoftwareText(platform))
        {
            if (fried_import::stripFontTables(source, &converted, &message))
            {
                result = &converted;
            }
            else
            {
                std::cerr << "fried_import: " << relative.string() << " " << message << ", copied as it is\n";
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
