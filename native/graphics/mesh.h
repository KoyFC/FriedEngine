#pragma once

#include <cstdint>

// A mesh a renderer turns, lights and depth tests itself, on a GPU that does
// 3D. Only the DS's top screen has such a renderer; everywhere else a mesh
// cannot be created, and MeshPass draws one as triangles it works out itself.

// The numbers MeshPass places a mesh with, in this order: the mesh's
// position, its rotation in degrees about x, y and z (turned about z, then x,
// then y, as Unity does) and its scale on each axis, then the camera's
// position, rotation, field of view, viewport and near plane, the light's
// direction in the world and ambient level, and the camera's far plane. They
// are passed as they are, since every sum on them is a call into software
// floating point on the DS, and what the camera and the light give is worked
// out once for all the meshes they are the same for.
enum FriedMeshPlacement
{
    FRIED_MESH_X,
    FRIED_MESH_Y,
    FRIED_MESH_Z,
    FRIED_MESH_ROTATION_X,
    FRIED_MESH_ROTATION_Y,
    FRIED_MESH_ROTATION_Z,
    FRIED_MESH_SCALE_X,
    FRIED_MESH_SCALE_Y,
    FRIED_MESH_SCALE_Z,
    FRIED_MESH_CAMERA_X,
    FRIED_MESH_CAMERA_Y,
    FRIED_MESH_CAMERA_Z,
    FRIED_MESH_CAMERA_ROTATION_X,
    FRIED_MESH_CAMERA_ROTATION_Y,
    FRIED_MESH_CAMERA_ROTATION_Z,
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
    FRIED_MESH_FAR,
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
// A run of polygons of one alpha and one corner count, as the packed commands
// the geometry engine's FIFO takes: up to four command bytes in a word, then
// their parameters. A polygon is its normal and its corners as v16 x and y
// packed in a word and z alone, in units of the mesh's own, with the material
// before it where the color changes. Drawing a run is one DMA of its words.
struct FriedNdsList
{
    const uint32_t *m_words;
    int m_wordCount;
    uint8_t m_alpha;
    uint8_t m_cornerCount;
};

// Where a list holds the emission of a color, which is the light's ambient
// share of it and so is written again when the ambient changes.
struct FriedNdsEmission
{
    uint32_t *m_word;
    uint16_t m_color;
};

// A v16 holds less than 8, so the corners are stored divided by a unit of
// 2 to the power of m_unitShift, which the mesh is scaled back up by as it is
// drawn. The lists share one allocation, m_words.
struct FriedNdsMesh
{
    uint32_t *m_words;
    int m_wordCount;
    FriedNdsList *m_lists;
    int m_listCount;
    FriedNdsEmission *m_emissions;
    int m_emissionCount;
    int m_ambient;
    int m_unitShift;
};

FriedNdsMesh *fried_mesh_get_nds(int meshId);

// Writes the emissions of the lists for an ambient share from 0 to 32 and
// puts the words where the DMA reads them.
void fried_mesh_set_ambient_nds(FriedNdsMesh *mesh, int ambient);
#endif
