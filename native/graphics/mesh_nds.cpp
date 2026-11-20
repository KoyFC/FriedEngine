#include "graphics/mesh.h"

#include "handle_pool.h"
#include "last_error.h"

#include <nds.h>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <memory>
#include <new>

// A mesh is turned into what the geometry engine takes once, when it is
// created: each triangle's normal, worked out from its corners the way
// MeshPass does, and its corners in fixed point. Two triangles in a row that
// make a flat, convex quad of one color, as a fan of two does, go as that
// quad: the engine keeps at most 6144 vertices a frame, and a quad takes four
// of them where two triangles take six. The polygons are then packed into the
// command words the engine's FIFO takes, so that drawing a mesh is one DMA
// per run of one alpha instead of a handful of CPU writes per polygon, which
// renderer_nds.cpp sends.

namespace
{
    constexpr double s_largestCorner = 7.99;
    constexpr double s_sameNormal = 0.9999;

    HandlePool<FriedNdsMesh> s_meshes;

    struct Vector
    {
        double m_x;
        double m_y;
        double m_z;
    };

    // Corners index the mesh's vertices.
    struct Face
    {
        int m_corners[4];
        int m_cornerCount;
        Vector m_normal;
        uint32_t m_argb;
    };

    Vector vertexAt(const double *vertices, int index)
    {
        return {vertices[index * 3], vertices[index * 3 + 1], vertices[index * 3 + 2]};
    }

    Vector minus(const Vector &a, const Vector &b)
    {
        return {a.m_x - b.m_x, a.m_y - b.m_y, a.m_z - b.m_z};
    }

    Vector cross(const Vector &a, const Vector &b)
    {
        return {a.m_y * b.m_z - a.m_z * b.m_y, a.m_z * b.m_x - a.m_x * b.m_z, a.m_x * b.m_y - a.m_y * b.m_x};
    }

    double dot(const Vector &a, const Vector &b)
    {
        return a.m_x * b.m_x + a.m_y * b.m_y + a.m_z * b.m_z;
    }

    Vector normalOf(const double *vertices, const int corners[3])
    {
        Vector a = vertexAt(vertices, corners[0]);
        Vector normal = cross(minus(vertexAt(vertices, corners[1]), a), minus(vertexAt(vertices, corners[2]), a));
        double length = std::sqrt(dot(normal, normal));
        return length > 0.0 ? Vector{normal.m_x / length, normal.m_y / length, normal.m_z / length} : Vector{0.0, 0.0, 0.0};
    }

    // The triangles a, b, c and a, c, d make the quad a, b, c, d when they
    // face the same way, have the same color and the quad's other diagonal,
    // from b to d, has a and c on either side of it.
    bool joinsIntoQuad(const double *vertices, const Face &first, const Face &second)
    {
        if (first.m_argb != second.m_argb || first.m_corners[0] != second.m_corners[0] || first.m_corners[2] != second.m_corners[1])
        {
            return false;
        }
        if (dot(first.m_normal, first.m_normal) == 0.0 || dot(first.m_normal, second.m_normal) < s_sameNormal)
        {
            return false;
        }
        Vector b = vertexAt(vertices, first.m_corners[1]);
        Vector d = vertexAt(vertices, second.m_corners[2]);
        Vector diagonal = minus(b, d);
        double sideOfA = dot(first.m_normal, cross(diagonal, minus(vertexAt(vertices, first.m_corners[0]), d)));
        double sideOfC = dot(first.m_normal, cross(diagonal, minus(vertexAt(vertices, first.m_corners[2]), d)));
        return (sideOfA > 0.0 && sideOfC < 0.0) || (sideOfA < 0.0 && sideOfC > 0.0);
    }

    int toV16(double value, double unit)
    {
        return std::clamp((int)std::lround(value / unit * 4096.0), -32768, 32767);
    }

    int toV10(double value)
    {
        return std::clamp((int)std::lround(value * 512.0), -512, 511);
    }

    // The light's ambient share of a color, which a polygon gives out unlit.
    // It is the second half of the word that also holds the specular color,
    // which is left black.
    uint32_t emissionOf(uint16_t color, int ambient)
    {
        int r = ((color & 0x1f) * ambient) >> 5;
        int g = (((color >> 5) & 0x1f) * ambient) >> 5;
        int b = (((color >> 10) & 0x1f) * ambient) >> 5;
        return (uint32_t)RGB15(r, g, b) << 16;
    }

    uint16_t colorOf(uint32_t argb)
    {
        return RGB15(((argb >> 16) & 0xff) >> 3, ((argb >> 8) & 0xff) >> 3, (argb & 0xff) >> 3);
    }

    // Gathers commands four to a word, each word followed by the parameters
    // of its commands. Without an output it only counts the words.
    class CommandPacker
    {
    public:
        explicit CommandPacker(uint32_t *output) : m_output(output) {}

        void add(uint32_t command, uint32_t first)
        {
            m_commands[m_commandCount++] = command;
            m_parameters[m_parameterCount] = first;
            m_emissionColors[m_parameterCount++] = -1;
            finishCommandIfFull();
        }

        void addVertex(uint32_t xy, uint32_t z)
        {
            m_commands[m_commandCount++] = FIFO_VERTEX16;
            m_parameters[m_parameterCount] = xy;
            m_emissionColors[m_parameterCount++] = -1;
            m_parameters[m_parameterCount] = z;
            m_emissionColors[m_parameterCount++] = -1;
            finishCommandIfFull();
        }

        void addEmission(uint16_t color)
        {
            m_commands[m_commandCount++] = FIFO_SPECULAR_EMISSION;
            m_parameters[m_parameterCount] = 0;
            m_emissionColors[m_parameterCount++] = color;
            finishCommandIfFull();
        }

        void flush()
        {
            if (m_commandCount == 0)
            {
                return;
            }
            uint32_t word = 0;
            for (int index = 0; index < m_commandCount; ++index)
            {
                word |= m_commands[index] << (8 * index);
            }
            put(word);
            for (int index = 0; index < m_parameterCount; ++index)
            {
                if (m_emissionColors[index] >= 0)
                {
                    if (m_emissions)
                    {
                        m_emissions[m_emissionCount] = {m_output + m_size, (uint16_t)m_emissionColors[index]};
                    }
                    ++m_emissionCount;
                }
                put(m_parameters[index]);
            }
            m_commandCount = 0;
            m_parameterCount = 0;
        }

        int size() const
        {
            return m_size;
        }

        int emissionCount() const
        {
            return m_emissionCount;
        }

        void keepEmissionsIn(FriedNdsEmission *emissions)
        {
            m_emissions = emissions;
        }

    private:
        static constexpr int s_commandsPerWord = 4;
        static constexpr int s_mostParameters = 8;

        void finishCommandIfFull()
        {
            if (m_commandCount == s_commandsPerWord)
            {
                flush();
            }
        }

        void put(uint32_t word)
        {
            if (m_output)
            {
                m_output[m_size] = word;
            }
            ++m_size;
        }

        uint32_t *m_output;
        FriedNdsEmission *m_emissions = nullptr;
        uint32_t m_commands[s_commandsPerWord];
        uint32_t m_parameters[s_mostParameters];
        int m_emissionColors[s_mostParameters];
        int m_commandCount = 0;
        int m_parameterCount = 0;
        int m_size = 0;
        int m_emissionCount = 0;
    };

    // Writes the lists of a mesh, or with no output counts what they take.
    // Faces come in the order they are drawn in, and a list ends where the
    // alpha or the corner count changes.
    class ListBuilder
    {
    public:
        ListBuilder(const double *vertices, double unit, uint32_t *words, FriedNdsList *lists, FriedNdsEmission *emissions)
            : m_vertices(vertices), m_unit(unit), m_words(words), m_lists(lists), m_packer(words)
        {
            m_packer.keepEmissionsIn(emissions);
        }

        void add(const Face &face)
        {
            uint8_t alpha = (uint8_t)(face.m_argb >> 24);
            if (!m_isOpen || alpha != m_alpha || face.m_cornerCount != m_cornerCount)
            {
                close();
                m_isOpen = true;
                m_alpha = alpha;
                m_cornerCount = (uint8_t)face.m_cornerCount;
                m_firstWord = m_packer.size();
                m_color = -1;
            }
            uint16_t color = colorOf(face.m_argb);
            if (color != m_color)
            {
                m_color = color;
                m_packer.add(FIFO_DIFFUSE_AMBIENT, color);
                m_packer.addEmission(color);
            }
            bool isCounting = !m_words;
            m_packer.add(FIFO_NORMAL,
                         isCounting ? 0
                                    : ((uint32_t)toV10(face.m_normal.m_z) & 0x3ff) << 20 | ((uint32_t)toV10(face.m_normal.m_y) & 0x3ff) << 10 |
                                          ((uint32_t)toV10(face.m_normal.m_x) & 0x3ff));
            for (int corner = 0; corner < face.m_cornerCount; ++corner)
            {
                if (isCounting)
                {
                    m_packer.addVertex(0, 0);
                    continue;
                }
                Vector position = vertexAt(m_vertices, face.m_corners[corner]);
                m_packer.addVertex((uint32_t)toV16(position.m_y, m_unit) << 16 | ((uint32_t)toV16(position.m_x, m_unit) & 0xffff),
                                   (uint16_t)toV16(position.m_z, m_unit));
            }
        }

        void finish()
        {
            close();
        }

        int listCount() const
        {
            return m_listCount;
        }

        int wordCount() const
        {
            return m_packer.size();
        }

        int emissionCount() const
        {
            return m_packer.emissionCount();
        }

    private:
        void close()
        {
            if (!m_isOpen)
            {
                return;
            }
            m_packer.flush();
            if (m_lists)
            {
                m_lists[m_listCount] = {m_words + m_firstWord, m_packer.size() - m_firstWord, m_alpha, m_cornerCount};
            }
            ++m_listCount;
            m_isOpen = false;
        }

        const double *m_vertices;
        double m_unit;
        uint32_t *m_words;
        FriedNdsList *m_lists;
        CommandPacker m_packer;
        bool m_isOpen = false;
        uint8_t m_alpha = 0;
        uint8_t m_cornerCount = 0;
        int m_firstWord = 0;
        int m_color = -1;
        int m_listCount = 0;
    };

    // Triangles first and quads after, so each kind is begun once.
    template <typename Visit>
    void forEachFaceInDrawOrder(const Face *faces, int faceCount, Visit visit)
    {
        for (int cornerCount = 3; cornerCount <= 4; ++cornerCount)
        {
            for (int index = 0; index < faceCount; ++index)
            {
                if (faces[index].m_cornerCount == cornerCount)
                {
                    visit(faces[index]);
                }
            }
        }
    }

    void destroyMesh(FriedNdsMesh *mesh)
    {
        if (mesh)
        {
            delete[] mesh->m_words;
            delete[] mesh->m_lists;
            delete[] mesh->m_emissions;
            delete mesh;
        }
    }
}

int fried_mesh_create(const double *vertices, int vertexCount, const int *indices, const int *argbColors, int triangleCount)
{
    if (!vertices || !indices || !argbColors || vertexCount <= 0 || triangleCount <= 0)
    {
        fried_set_last_error("A mesh needs vertices and triangles");
        return -1;
    }
    for (int index = 0; index < triangleCount * 3; ++index)
    {
        if (indices[index] < 0 || indices[index] >= vertexCount)
        {
            fried_set_last_error("A mesh index is outside its vertices");
            return -1;
        }
    }

    std::unique_ptr<Face[]> faces(new (std::nothrow) Face[triangleCount]);
    FriedNdsMesh *mesh = new (std::nothrow) FriedNdsMesh{nullptr, 0, nullptr, 0, nullptr, 0, -1, 0};
    if (!mesh || !faces)
    {
        destroyMesh(mesh);
        fried_set_last_error("Not enough memory for the mesh");
        return -1;
    }

    int faceCount = 0;
    for (int triangle = 0; triangle < triangleCount; ++triangle)
    {
        Face face = {{indices[triangle * 3], indices[triangle * 3 + 1], indices[triangle * 3 + 2], 0}, 3, {}, (uint32_t)argbColors[triangle]};
        face.m_normal = normalOf(vertices, face.m_corners);
        Face *previous = faceCount > 0 ? &faces[faceCount - 1] : nullptr;
        if (previous && previous->m_cornerCount == 3 && joinsIntoQuad(vertices, *previous, face))
        {
            previous->m_corners[3] = face.m_corners[2];
            previous->m_cornerCount = 4;
            continue;
        }
        faces[faceCount++] = face;
    }

    double largest = 0.0;
    for (int index = 0; index < vertexCount * 3; ++index)
    {
        largest = std::max(largest, std::fabs(vertices[index]));
    }
    double unit = 1.0;
    while (largest / unit > s_largestCorner)
    {
        unit *= 2.0;
        ++mesh->m_unitShift;
    }

    ListBuilder counter(vertices, unit, nullptr, nullptr, nullptr);
    forEachFaceInDrawOrder(faces.get(), faceCount, [&counter](const Face &face) { counter.add(face); });
    counter.finish();

    mesh->m_words = new (std::nothrow) uint32_t[counter.wordCount()];
    mesh->m_lists = new (std::nothrow) FriedNdsList[counter.listCount()];
    mesh->m_emissions = new (std::nothrow) FriedNdsEmission[counter.emissionCount()];
    if (!mesh->m_words || !mesh->m_lists || !mesh->m_emissions)
    {
        destroyMesh(mesh);
        fried_set_last_error("Not enough memory for the mesh");
        return -1;
    }

    ListBuilder builder(vertices, unit, mesh->m_words, mesh->m_lists, mesh->m_emissions);
    forEachFaceInDrawOrder(faces.get(), faceCount, [&builder](const Face &face) { builder.add(face); });
    builder.finish();
    mesh->m_wordCount = builder.wordCount();
    mesh->m_listCount = builder.listCount();
    mesh->m_emissionCount = builder.emissionCount();
    return s_meshes.store(mesh);
}

void fried_mesh_destroy(int meshId)
{
    destroyMesh(s_meshes.release(meshId));
}

FriedNdsMesh *fried_mesh_get_nds(int meshId)
{
    return s_meshes.get(meshId);
}

void fried_mesh_set_ambient_nds(FriedNdsMesh *mesh, int ambient)
{
    for (int index = 0; index < mesh->m_emissionCount; ++index)
    {
        *mesh->m_emissions[index].m_word = emissionOf(mesh->m_emissions[index].m_color, ambient);
    }
    mesh->m_ambient = ambient;
    DC_FlushRange(mesh->m_words, (u32)mesh->m_wordCount * sizeof(uint32_t));
}
