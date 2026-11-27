#include "model/model_convert.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <map>
#include <sstream>

#define CGLTF_IMPLEMENTATION
#include "third_party/cgltf.h"

#include "third_party/stb_image.h"
#include "third_party/stb_image_write.h"

namespace fs = std::filesystem;

namespace
{
    // A surface as it is read, before it is written.
    struct Surface
    {
        std::vector<float> m_positions;
        std::vector<float> m_uvs;
        std::vector<uint32_t> m_indices;
        uint32_t m_albedo = 0xffffffffu;
        // A texture that is a file of the model's folder, as a path relative to it, or one that is held as the bytes of a PNG.
        std::string m_path;
        std::vector<unsigned char> m_png;
        // What makes two surfaces the same one, so they are merged.
        std::string m_key;
    };

    struct Material
    {
        uint32_t m_albedo = 0xffffffffu;
        fs::path m_texture;
    };

    struct Reading
    {
        fs::path m_directory;
        fried_model::Result *m_result = nullptr;
        const fried_model::Options *m_options = nullptr;
        std::vector<Surface> m_surfaces;
        std::map<std::string, int> m_surfaceByKey;
        int m_imageCount = 0;
    };

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

    uint32_t packColor(float red, float green, float blue, float alpha)
    {
        auto channel = [](float value) { return (uint32_t)std::lround(std::min(std::max(value, 0.0f), 1.0f) * 255.0f); };
        return (channel(alpha) << 24) | (channel(red) << 16) | (channel(green) << 8) | channel(blue);
    }

    uint32_t multiplyColors(uint32_t first, uint32_t second)
    {
        uint32_t result = 0;
        for (int shift = 0; shift <= 24; shift += 8)
        {
            uint32_t a = (first >> shift) & 0xff;
            uint32_t b = (second >> shift) & 0xff;
            result |= ((a * b) / 255u) << shift;
        }
        return result;
    }

    std::string relativeTo(const fs::path &directory, const fs::path &path)
    {
        return path.lexically_normal().lexically_relative(directory.lexically_normal()).generic_string();
    }

    // The color of an image on average, weighted by how opaque each pixel is.
    uint32_t averageColor(const std::vector<unsigned char> &file)
    {
        int width = 0, height = 0, channels = 0;
        unsigned char *pixels = stbi_load_from_memory(file.data(), (int)file.size(), &width, &height, &channels, 4);
        if (!pixels)
        {
            return 0xffffffffu;
        }
        double sum[3] = {0, 0, 0};
        double weight = 0;
        for (long index = 0; index < (long)width * height; ++index)
        {
            double alpha = pixels[index * 4 + 3] / 255.0;
            for (int channel = 0; channel < 3; ++channel)
            {
                sum[channel] += pixels[index * 4 + channel] * alpha;
            }
            weight += alpha;
        }
        stbi_image_free(pixels);
        if (weight <= 0)
        {
            return 0xffffffffu;
        }
        return 0xff000000u | ((uint32_t)std::lround(sum[0] / weight) << 16) | ((uint32_t)std::lround(sum[1] / weight) << 8) | (uint32_t)std::lround(sum[2] / weight);
    }

    void writeToVector(void *context, void *data, int size)
    {
        std::vector<unsigned char> *out = static_cast<std::vector<unsigned char> *>(context);
        out->insert(out->end(), (unsigned char *)data, (unsigned char *)data + size);
    }

    // Any image the engine cannot read as the model's own file, as a PNG.
    bool encodePng(const std::vector<unsigned char> &file, std::vector<unsigned char> *png)
    {
        int width = 0, height = 0, channels = 0;
        unsigned char *pixels = stbi_load_from_memory(file.data(), (int)file.size(), &width, &height, &channels, 4);
        if (!pixels)
        {
            return false;
        }
        png->clear();
        bool isWritten = stbi_write_png_to_func(writeToVector, png, width, height, 4, pixels, width * 4) != 0;
        stbi_image_free(pixels);
        return isWritten;
    }

    bool isPng(const std::vector<unsigned char> &file)
    {
        static const unsigned char signature[8] = {0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'};
        return file.size() >= 8 && std::memcmp(file.data(), signature, 8) == 0;
    }

    // Gives a surface the image whose bytes these are. A PNG a file of the model's folder holds is named by its path, and any other image is written as a PNG, to a file if the options can make one and inside the model if they cannot.
    void setImage(Reading &reading, Surface &surface, const std::vector<unsigned char> &file, const fs::path &source, const std::string &name)
    {
        if (!source.empty() && isPng(file) && !reading.m_options->m_stripImages)
        {
            surface.m_path = relativeTo(reading.m_directory, source);
            surface.m_key = "path:" + surface.m_path;
            return;
        }
        if (reading.m_options->m_stripImages)
        {
            surface.m_albedo = multiplyColors(surface.m_albedo, averageColor(file));
            return;
        }
        std::vector<unsigned char> png;
        if (isPng(file))
        {
            png = file;
        }
        else if (!encodePng(file, &png))
        {
            reading.m_result->m_warnings.push_back("the image " + name + " cannot be read, so its surface has no image");
            return;
        }
        if (reading.m_options->m_extract)
        {
            std::string path = reading.m_options->m_extract(png, name);
            if (!path.empty())
            {
                surface.m_path = path;
                surface.m_key = "path:" + path;
                return;
            }
        }
        surface.m_png = png;
        surface.m_key = "png:" + name;
    }

    // The surface of a key, which a source makes with its material the first time and then adds to.
    Surface &surfaceOf(Reading &reading, const std::string &key, const Surface &fresh)
    {
        auto found = reading.m_surfaceByKey.find(key);
        if (found != reading.m_surfaceByKey.end())
        {
            return reading.m_surfaces[found->second];
        }
        reading.m_surfaceByKey[key] = (int)reading.m_surfaces.size();
        reading.m_surfaces.push_back(fresh);
        return reading.m_surfaces.back();
    }

    // OBJ

    struct ObjMaterials
    {
        std::map<std::string, Material> m_byName;
    };

    void readMtl(Reading &reading, const fs::path &mtlPath, ObjMaterials &materials)
    {
        std::ifstream stream(mtlPath);
        if (!stream)
        {
            reading.m_result->m_warnings.push_back("the material file " + mtlPath.string() + " cannot be read");
            return;
        }
        reading.m_result->m_dependencies.push_back(mtlPath.string());
        Material *current = nullptr;
        std::string line;
        while (std::getline(stream, line))
        {
            std::istringstream words(line);
            std::string word;
            if (!(words >> word))
            {
                continue;
            }
            if (word == "newmtl")
            {
                std::string name;
                std::getline(words >> std::ws, name);
                while (!name.empty() && (name.back() == '\r' || name.back() == ' '))
                {
                    name.pop_back();
                }
                current = &materials.m_byName[name];
            }
            else if (!current)
            {
                continue;
            }
            else if (word == "Kd")
            {
                float red = 1, green = 1, blue = 1;
                words >> red >> green >> blue;
                uint32_t alpha = current->m_albedo & 0xff000000u;
                current->m_albedo = (packColor(red, green, blue, 1.0f) & 0x00ffffffu) | alpha;
            }
            else if (word == "d" || word == "Tr")
            {
                float value = 1;
                words >> value;
                float alpha = word == "d" ? value : 1.0f - value;
                current->m_albedo = (current->m_albedo & 0x00ffffffu) | (packColor(0, 0, 0, alpha) & 0xff000000u);
            }
            else if (word == "map_Kd")
            {
                // Options start with a dash and the name is the last word.
                std::string last, token;
                while (words >> token)
                {
                    last = token;
                }
                std::replace(last.begin(), last.end(), '\\', '/');
                if (!last.empty())
                {
                    current->m_texture = mtlPath.parent_path() / last;
                }
            }
        }
    }

    // One corner of a face: indices into the file's positions and texture coordinates, or -1.
    struct Corner
    {
        int m_position;
        int m_uv;
    };

    int resolveIndex(int value, int count)
    {
        if (value > 0)
        {
            return value - 1 < count ? value - 1 : -2;
        }
        if (value < 0)
        {
            return count + value >= 0 ? count + value : -2;
        }
        return -2;
    }

    bool readObj(Reading &reading, const fs::path &path, std::string *error)
    {
        std::ifstream stream(path);
        if (!stream)
        {
            *error = "cannot read " + path.string();
            return false;
        }

        std::vector<float> positions, uvs;
        ObjMaterials materials;
        std::string materialName;
        // Corners of a surface that have been given an index in it already.
        std::map<std::pair<int, std::array<int, 2>>, uint32_t> vertexOf;
        int skippedFaces = 0;

        std::string line;
        while (std::getline(stream, line))
        {
            std::istringstream words(line);
            std::string word;
            if (!(words >> word))
            {
                continue;
            }
            if (word == "v")
            {
                float x = 0, y = 0, z = 0;
                words >> x >> y >> z;
                positions.insert(positions.end(), {x, y, z});
            }
            else if (word == "vt")
            {
                float u = 0, v = 0;
                words >> u >> v;
                uvs.insert(uvs.end(), {u, 1.0f - v});
            }
            else if (word == "mtllib")
            {
                std::string name;
                while (words >> name)
                {
                    std::replace(name.begin(), name.end(), '\\', '/');
                    readMtl(reading, path.parent_path() / name, materials);
                }
            }
            else if (word == "usemtl")
            {
                std::getline(words >> std::ws, materialName);
                while (!materialName.empty() && (materialName.back() == '\r' || materialName.back() == ' '))
                {
                    materialName.pop_back();
                }
            }
            else if (word == "f")
            {
                std::vector<Corner> corners;
                std::string token;
                bool isValid = true;
                while (words >> token)
                {
                    int parts[3] = {0, 0, 0};
                    bool has[3] = {false, false, false};
                    size_t start = 0;
                    for (int part = 0; part < 3 && start <= token.size(); ++part)
                    {
                        size_t slash = token.find('/', start);
                        std::string text = token.substr(start, slash == std::string::npos ? std::string::npos : slash - start);
                        if (!text.empty())
                        {
                            parts[part] = std::atoi(text.c_str());
                            has[part] = true;
                        }
                        if (slash == std::string::npos)
                        {
                            break;
                        }
                        start = slash + 1;
                    }
                    Corner corner;
                    corner.m_position = has[0] ? resolveIndex(parts[0], (int)(positions.size() / 3)) : -2;
                    corner.m_uv = has[1] ? resolveIndex(parts[1], (int)(uvs.size() / 2)) : -1;
                    if (corner.m_position < 0 || corner.m_uv == -2)
                    {
                        isValid = false;
                        break;
                    }
                    corners.push_back(corner);
                }
                if (!isValid || corners.size() < 3)
                {
                    ++skippedFaces;
                    continue;
                }

                auto found = materials.m_byName.find(materialName);
                Material material = found != materials.m_byName.end() ? found->second : Material();
                std::string key = "obj:" + materialName;
                Surface fresh;
                fresh.m_albedo = material.m_albedo;
                int surfaceIndex = -1;
                {
                    auto existing = reading.m_surfaceByKey.find(key);
                    if (existing == reading.m_surfaceByKey.end())
                    {
                        // The image is read once, when the material is first used.
                        if (!material.m_texture.empty())
                        {
                            std::vector<unsigned char> file;
                            if (readFile(material.m_texture, &file))
                            {
                                reading.m_result->m_dependencies.push_back(material.m_texture.string());
                                setImage(reading, fresh, file, material.m_texture, material.m_texture.filename().string());
                            }
                            else
                            {
                                reading.m_result->m_warnings.push_back("the image " + material.m_texture.string() + " is missing");
                            }
                        }
                    }
                    surfaceOf(reading, key, fresh);
                    surfaceIndex = reading.m_surfaceByKey[key];
                }
                Surface &surface = reading.m_surfaces[surfaceIndex];

                std::vector<uint32_t> indices;
                for (const Corner &corner : corners)
                {
                    auto place = vertexOf.find({surfaceIndex, {corner.m_position, corner.m_uv}});
                    if (place == vertexOf.end())
                    {
                        uint32_t index = (uint32_t)(surface.m_positions.size() / 3);
                        surface.m_positions.insert(surface.m_positions.end(), positions.begin() + corner.m_position * 3, positions.begin() + corner.m_position * 3 + 3);
                        if (corner.m_uv >= 0)
                        {
                            surface.m_uvs.insert(surface.m_uvs.end(), uvs.begin() + corner.m_uv * 2, uvs.begin() + corner.m_uv * 2 + 2);
                        }
                        else
                        {
                            surface.m_uvs.insert(surface.m_uvs.end(), {0.0f, 0.0f});
                        }
                        place = vertexOf.emplace(std::make_pair(surfaceIndex, std::array<int, 2>{corner.m_position, corner.m_uv}), index).first;
                    }
                    indices.push_back(place->second);
                }
                // A polygon is a fan of triangles from its first corner.
                for (size_t corner = 1; corner + 1 < indices.size(); ++corner)
                {
                    surface.m_indices.insert(surface.m_indices.end(), {indices[0], indices[corner], indices[corner + 1]});
                }
            }
        }
        if (skippedFaces > 0)
        {
            reading.m_result->m_warnings.push_back(std::to_string(skippedFaces) + " faces with a bad index or fewer than three corners were left out");
        }
        return true;
    }

    // glTF

    void addPrimitive(Reading &reading, const cgltf_primitive &primitive, const float *world, const cgltf_data *data, const fs::path &modelPath)
    {
        if (primitive.type != cgltf_primitive_type_triangles && primitive.type != cgltf_primitive_type_triangle_strip
            && primitive.type != cgltf_primitive_type_triangle_fan)
        {
            reading.m_result->m_warnings.push_back("a primitive that is not made of triangles was left out");
            return;
        }
        const cgltf_accessor *positions = nullptr, *uvs = nullptr;
        for (cgltf_size index = 0; index < primitive.attributes_count; ++index)
        {
            const cgltf_attribute &attribute = primitive.attributes[index];
            if (attribute.type == cgltf_attribute_type_position && attribute.index == 0)
            {
                positions = attribute.data;
            }
            else if (attribute.type == cgltf_attribute_type_texcoord && attribute.index == 0)
            {
                uvs = attribute.data;
            }
        }
        if (!positions)
        {
            return;
        }

        // The surface of a material, whose color and image are set the first time it is used.
        const cgltf_material *material = primitive.material;
        std::string key = "gltf:" + std::to_string(material ? material - data->materials : -1);
        Surface fresh;
        bool isNew = reading.m_surfaceByKey.find(key) == reading.m_surfaceByKey.end();
        if (isNew && material && material->has_pbr_metallic_roughness)
        {
            const cgltf_pbr_metallic_roughness &pbr = material->pbr_metallic_roughness;
            fresh.m_albedo = packColor(pbr.base_color_factor[0], pbr.base_color_factor[1], pbr.base_color_factor[2], pbr.base_color_factor[3]);
            const cgltf_image *image = pbr.base_color_texture.texture ? pbr.base_color_texture.texture->image : nullptr;
            if (image)
            {
                std::vector<unsigned char> file;
                fs::path source;
                std::string name = image->name ? image->name : "image" + std::to_string(reading.m_imageCount);
                ++reading.m_imageCount;
                if (image->buffer_view)
                {
                    const unsigned char *base = (const unsigned char *)image->buffer_view->buffer->data + image->buffer_view->offset;
                    file.assign(base, base + image->buffer_view->size);
                }
                else if (image->uri && std::strncmp(image->uri, "data:", 5) == 0)
                {
                    const char *comma = std::strchr(image->uri, ',');
                    void *decoded = nullptr;
                    cgltf_options options = {};
                    if (comma)
                    {
                        // Four characters make three bytes, less one for each "=" that pads the last four.
                        size_t length = std::strlen(comma + 1);
                        size_t padding = 0;
                        while (padding < length && padding < 2 && comma[length - padding] == '=')
                        {
                            ++padding;
                        }
                        size_t size = length / 4 * 3 - padding;
                        if (cgltf_load_buffer_base64(&options, size, comma + 1, &decoded) == cgltf_result_success)
                        {
                            file.assign((unsigned char *)decoded, (unsigned char *)decoded + size);
                            std::free(decoded);
                        }
                    }
                }
                else if (image->uri)
                {
                    std::string uri = image->uri;
                    std::vector<char> decoded(uri.begin(), uri.end());
                    decoded.push_back('\0');
                    cgltf_decode_uri(decoded.data());
                    source = modelPath.parent_path() / decoded.data();
                    if (readFile(source, &file))
                    {
                        reading.m_result->m_dependencies.push_back(source.string());
                    }
                    else
                    {
                        reading.m_result->m_warnings.push_back("the image " + source.string() + " is missing");
                        file.clear();
                    }
                }
                if (!file.empty())
                {
                    setImage(reading, fresh, file, source, name);
                }
            }
        }
        Surface &surface = surfaceOf(reading, key, fresh);

        // The transform's determinant says whether it is a mirror, which turns the triangles round.
        double determinant = world[0] * (world[5] * world[10] - world[9] * world[6]) - world[4] * (world[1] * world[10] - world[9] * world[2])
                           + world[8] * (world[1] * world[6] - world[5] * world[2]);
        bool isMirrored = determinant < 0.0;

        uint32_t first = (uint32_t)(surface.m_positions.size() / 3);
        for (cgltf_size vertex = 0; vertex < positions->count; ++vertex)
        {
            float p[3] = {0, 0, 0};
            cgltf_accessor_read_float(positions, vertex, p, 3);
            surface.m_positions.push_back(world[0] * p[0] + world[4] * p[1] + world[8] * p[2] + world[12]);
            surface.m_positions.push_back(world[1] * p[0] + world[5] * p[1] + world[9] * p[2] + world[13]);
            surface.m_positions.push_back(world[2] * p[0] + world[6] * p[1] + world[10] * p[2] + world[14]);
            float uv[2] = {0, 0};
            if (uvs && vertex < uvs->count)
            {
                cgltf_accessor_read_float(uvs, vertex, uv, 2);
            }
            surface.m_uvs.push_back(uv[0]);
            surface.m_uvs.push_back(uv[1]);
        }

        cgltf_size count = primitive.indices ? primitive.indices->count : positions->count;
        auto indexAt = [&](cgltf_size position) -> uint32_t { return first + (primitive.indices ? (uint32_t)cgltf_accessor_read_index(primitive.indices, position) : (uint32_t)position); };
        auto add = [&](uint32_t a, uint32_t b, uint32_t c) {
            if (isMirrored)
            {
                std::swap(b, c);
            }
            surface.m_indices.insert(surface.m_indices.end(), {a, b, c});
        };
        if (primitive.type == cgltf_primitive_type_triangles)
        {
            for (cgltf_size corner = 0; corner + 2 < count; corner += 3)
            {
                add(indexAt(corner), indexAt(corner + 1), indexAt(corner + 2));
            }
        }
        else if (primitive.type == cgltf_primitive_type_triangle_strip)
        {
            for (cgltf_size corner = 0; corner + 2 < count; ++corner)
            {
                if (corner % 2 == 0)
                {
                    add(indexAt(corner), indexAt(corner + 1), indexAt(corner + 2));
                }
                else
                {
                    add(indexAt(corner + 1), indexAt(corner), indexAt(corner + 2));
                }
            }
        }
        else
        {
            for (cgltf_size corner = 1; corner + 1 < count; ++corner)
            {
                add(indexAt(0), indexAt(corner), indexAt(corner + 1));
            }
        }
    }

    void walkNode(Reading &reading, const cgltf_node &node, const cgltf_data *data, const fs::path &modelPath)
    {
        if (node.mesh)
        {
            float world[16];
            cgltf_node_transform_world(&node, world);
            for (cgltf_size index = 0; index < node.mesh->primitives_count; ++index)
            {
                addPrimitive(reading, node.mesh->primitives[index], world, data, modelPath);
            }
        }
        for (cgltf_size index = 0; index < node.children_count; ++index)
        {
            walkNode(reading, *node.children[index], data, modelPath);
        }
    }

    bool readGltf(Reading &reading, const fs::path &path, std::string *error)
    {
        cgltf_options options = {};
        cgltf_data *data = nullptr;
        std::string text = path.string();
        if (cgltf_parse_file(&options, text.c_str(), &data) != cgltf_result_success)
        {
            *error = "cannot read " + text + " as glTF";
            return false;
        }
        if (cgltf_load_buffers(&options, data, text.c_str()) != cgltf_result_success)
        {
            *error = "cannot read the buffers of " + text;
            cgltf_free(data);
            return false;
        }
        for (cgltf_size index = 0; index < data->buffers_count; ++index)
        {
            if (data->buffers[index].uri && std::strncmp(data->buffers[index].uri, "data:", 5) != 0)
            {
                std::vector<char> decoded(data->buffers[index].uri, data->buffers[index].uri + std::strlen(data->buffers[index].uri) + 1);
                cgltf_decode_uri(decoded.data());
                reading.m_result->m_dependencies.push_back((path.parent_path() / decoded.data()).string());
            }
        }

        const cgltf_scene *scene = data->scene ? data->scene : (data->scenes_count > 0 ? &data->scenes[0] : nullptr);
        if (scene)
        {
            for (cgltf_size index = 0; index < scene->nodes_count; ++index)
            {
                walkNode(reading, *scene->nodes[index], data, path);
            }
        }
        else
        {
            for (cgltf_size index = 0; index < data->nodes_count; ++index)
            {
                if (!data->nodes[index].parent)
                {
                    walkNode(reading, data->nodes[index], data, path);
                }
            }
        }
        cgltf_free(data);
        return true;
    }

    // Output

    void put32(std::vector<unsigned char> &out, uint32_t value)
    {
        for (int shift = 0; shift < 32; shift += 8)
        {
            out.push_back((unsigned char)(value >> shift));
        }
    }

    void put16(std::vector<unsigned char> &out, uint16_t value)
    {
        out.push_back((unsigned char)value);
        out.push_back((unsigned char)(value >> 8));
    }

    void putFloat(std::vector<unsigned char> &out, float value)
    {
        uint32_t bits;
        std::memcpy(&bits, &value, sizeof(bits));
        put32(out, bits);
    }

    void pad(std::vector<unsigned char> &out)
    {
        while (out.size() % 4 != 0)
        {
            out.push_back(0);
        }
    }

    // The vertices to the engine's space: a mirror on x, which turns every triangle round.
    void toEngineSpace(Surface &surface)
    {
        for (size_t index = 0; index < surface.m_positions.size(); index += 3)
        {
            surface.m_positions[index] = -surface.m_positions[index];
        }
        for (size_t index = 0; index + 2 < surface.m_indices.size(); index += 3)
        {
            std::swap(surface.m_indices[index + 1], surface.m_indices[index + 2]);
        }
    }
}

bool fried_model::convert(const std::string &pathText, const Options &options, Result *result, std::string *error)
{
    fs::path path = pathText;
    Reading reading;
    reading.m_directory = path.parent_path();
    reading.m_result = result;
    reading.m_options = &options;

    std::string extension = lowerExtension(path);
    bool isRead = false;
    if (extension == ".obj")
    {
        isRead = readObj(reading, path, error);
    }
    else if (extension == ".gltf" || extension == ".glb")
    {
        isRead = readGltf(reading, path, error);
    }
    else
    {
        *error = "a model is an OBJ, glTF or GLB file";
    }
    if (!isRead)
    {
        return false;
    }

    std::vector<Surface> surfaces;
    for (Surface &surface : reading.m_surfaces)
    {
        if (surface.m_indices.empty())
        {
            continue;
        }
        toEngineSpace(surface);
        surfaces.push_back(std::move(surface));
    }
    if (surfaces.empty())
    {
        *error = path.string() + " has no triangles";
        return false;
    }

    std::vector<unsigned char> &out = result->m_bytes;
    out.clear();
    out.insert(out.end(), {'F', 'R', 'M', 'S'});
    put16(out, 1);
    put16(out, 0);
    put32(out, (uint32_t)surfaces.size());
    result->m_triangleCount = 0;
    result->m_vertexCount = 0;
    for (const Surface &surface : surfaces)
    {
        uint32_t vertexCount = (uint32_t)(surface.m_positions.size() / 3);
        uint32_t triangleCount = (uint32_t)(surface.m_indices.size() / 3);
        bool hasImage = !surface.m_path.empty() || !surface.m_png.empty();
        bool hasUvs = hasImage && !options.m_stripImages;
        bool isWide = vertexCount > 65535;
        result->m_triangleCount += (int)triangleCount;
        result->m_vertexCount += (int)vertexCount;

        put32(out, vertexCount);
        put32(out, triangleCount);
        put32(out, (hasUvs ? 1u : 0u) | (isWide ? 2u : 0u));
        put32(out, surface.m_albedo);
        if (!hasUvs || (surface.m_path.empty() && surface.m_png.empty()))
        {
            put32(out, 0);
        }
        else if (!surface.m_path.empty())
        {
            put32(out, 1);
            put32(out, (uint32_t)surface.m_path.size());
            out.insert(out.end(), surface.m_path.begin(), surface.m_path.end());
            pad(out);
        }
        else
        {
            put32(out, 2);
            put32(out, (uint32_t)surface.m_png.size());
            out.insert(out.end(), surface.m_png.begin(), surface.m_png.end());
            pad(out);
        }
        for (float value : surface.m_positions)
        {
            putFloat(out, value);
        }
        if (hasUvs)
        {
            for (float value : surface.m_uvs)
            {
                putFloat(out, value);
            }
        }
        for (uint32_t index : surface.m_indices)
        {
            if (isWide)
            {
                put32(out, index);
            }
            else
            {
                put16(out, (uint16_t)index);
            }
        }
        pad(out);
    }
    return true;
}
