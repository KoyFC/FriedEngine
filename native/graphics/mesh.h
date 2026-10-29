#pragma once

#include <cstdint>

// A mesh a renderer turns, lights and depth tests itself, on a GPU that does
// 3D. Only the DS's top screen has such a renderer; everywhere else a mesh
// cannot be created, and Camera3D draws one as triangles it works out itself.

// The numbers Camera3D places a mesh with, in this order: the mesh's position,
// its rotation in degrees about x, y and z and its scale, then the camera's
// position, field of view, viewport and near plane, and the light's direction
// and ambient level. They are passed as they are, since every sum on them is
// a call into software floating point on the DS, and what the camera and the
// light give is worked out once for all the meshes they are the same for.
enum FriedMeshPlacement
{
    FRIED_MESH_X,
    FRIED_MESH_Y,
    FRIED_MESH_Z,
    FRIED_MESH_ROTATION_X,
    FRIED_MESH_ROTATION_Y,
    FRIED_MESH_ROTATION_Z,
    FRIED_MESH_SCALE,
    FRIED_MESH_CAMERA_X,
    FRIED_MESH_CAMERA_Y,
    FRIED_MESH_CAMERA_Z,
    FRIED_MESH_FIELD_OF_VIEW,
    FRIED_MESH_VIEWPORT_X,
    FRIED_MESH_VIEWPORT_Y,
    FRIED_MESH_VIEWPORT_WIDTH,
    FRIED_MESH_VIEWPORT_HEIGHT,
    FRIED_MESH_NEAR,
    FRIED_MESH_LIGHT_X,
    FRIED_MESH_LIGHT_Y,
    FRIED_MESH_LIGHT_Z,
    FRIED_MESH_AMBIENT,
    FRIED_MESH_PLACEMENT_SIZE
};

extern "C"
{
    // -1 where no renderer draws meshes.
    int fried_mesh_create(const double *vertices, int vertexCount, const int *indices, const int *argbColors, int triangleCount);
    void fried_mesh_destroy(int meshId);

    bool fried_renderer_draws_meshes(int rendererId);
    // A 2D camera moves and zooms the screen the mesh is projected onto, as it
    // does the points of triangles.
    void fried_renderer_draw_mesh(int rendererId, int meshId, const double *placement, bool hasCamera, double zoom, double cameraX, double cameraY);
}

#ifdef __NDS__
// A triangle or a quad as the geometry engine takes it: its normal, its
// colour as RGB15, its alpha from 0 to 255, and its corners as v16 x and y
// packed in a word and z alone, in units of the mesh's own.
struct FriedNdsPolygon
{
    uint32_t m_normal;
    uint16_t m_color;
    uint8_t m_alpha;
    uint8_t m_cornerCount;
    uint32_t m_xy[4];
    uint16_t m_z[4];
};

// A v16 holds less than 8, so the corners are stored divided by a unit of
// 2 to the power of m_unitShift, which the mesh is scaled back up by as it is
// drawn.
struct FriedNdsMesh
{
    FriedNdsPolygon *m_polygons;
    int m_polygonCount;
    int m_unitShift;
};

const FriedNdsMesh *fried_mesh_get_nds(int meshId);
#endif
