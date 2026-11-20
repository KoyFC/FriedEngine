#include "graphics/mesh.h"

// No renderer here draws meshes, so MeshPass draws them as triangles.

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

#ifndef FRIED_SOFTWARE_RENDERER
#include "graphics/mesh_sdl.h"

bool fried_mesh_sdl_attach(int, void *)
{
    return false;
}

void fried_mesh_sdl_detach(int)
{
}

void fried_mesh_sdl_end_frame(int)
{
}

void fried_mesh_sdl_leave()
{
}
#endif
