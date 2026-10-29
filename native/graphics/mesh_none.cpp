#include "graphics/mesh.h"

// No renderer here draws meshes, so Camera3D draws them as triangles.

int fried_mesh_create(const double *, int, const int *, const int *, int)
{
    return -1;
}

void fried_mesh_destroy(int)
{
}

bool fried_renderer_draws_meshes(int)
{
    return false;
}

void fried_renderer_draw_mesh(int, int, const double *, bool, double, double, double)
{
}
