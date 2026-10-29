#include "graphics/mesh.h"

#include "handle_pool.h"
#include "last_error.h"

#include <nds.h>

#include <algorithm>
#include <cmath>
#include <memory>
#include <new>

// A mesh is turned into what the geometry engine takes once, when it is
// created: each triangle's normal, worked out from its corners the way
// Camera3D does, and its corners in fixed point. Two triangles in a row that
// make a flat, convex quad of one colour, as a fan of two does, go as that
// quad: the engine keeps at most 6144 vertices a frame, and a quad takes four
// of them where two triangles take six. Drawing it is then a few writes per
// polygon, which renderer_nds.cpp makes.

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
    // face the same way, have the same colour and the quad's other diagonal,
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

    void destroyMesh(FriedNdsMesh *mesh)
    {
        if (mesh)
        {
            delete[] mesh->m_polygons;
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
    FriedNdsMesh *mesh = new (std::nothrow) FriedNdsMesh{nullptr, 0, 0};
    if (mesh && faces)
    {
        mesh->m_polygons = new (std::nothrow) FriedNdsPolygon[triangleCount];
    }
    if (!mesh || !faces || !mesh->m_polygons)
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

    // Triangles first and quads after, so each kind is begun once.
    for (int cornerCount = 3; cornerCount <= 4; ++cornerCount)
    {
        for (int index = 0; index < faceCount; ++index)
        {
            const Face &face = faces[index];
            if (face.m_cornerCount != cornerCount)
            {
                continue;
            }
            FriedNdsPolygon &output = mesh->m_polygons[mesh->m_polygonCount++];
            output.m_normal = ((uint32_t)toV10(face.m_normal.m_z) & 0x3ff) << 20 | ((uint32_t)toV10(face.m_normal.m_y) & 0x3ff) << 10 |
                              ((uint32_t)toV10(face.m_normal.m_x) & 0x3ff);
            uint32_t argb = face.m_argb;
            output.m_color = RGB15(((argb >> 16) & 0xff) >> 3, ((argb >> 8) & 0xff) >> 3, (argb & 0xff) >> 3);
            output.m_alpha = (uint8_t)(argb >> 24);
            output.m_cornerCount = (uint8_t)face.m_cornerCount;
            for (int corner = 0; corner < face.m_cornerCount; ++corner)
            {
                Vector position = vertexAt(vertices, face.m_corners[corner]);
                output.m_xy[corner] = (uint32_t)toV16(position.m_y, unit) << 16 | ((uint32_t)toV16(position.m_x, unit) & 0xffff);
                output.m_z[corner] = (uint16_t)toV16(position.m_z, unit);
            }
        }
    }
    return s_meshes.store(mesh);
}

void fried_mesh_destroy(int meshId)
{
    destroyMesh(s_meshes.release(meshId));
}

const FriedNdsMesh *fried_mesh_get_nds(int meshId)
{
    return s_meshes.get(meshId);
}
