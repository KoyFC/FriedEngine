#include "math/real.h"
#include "graphics/renderer.h"

// The renderers that draw with the CPU or a GPU library of their own do not
// bend a texture over a triangle, so MeshPass fills the triangles of a
// textured mesh with the color the texture is on average.

bool fried_renderer_draws_textured_triangles(int)
{
    return false;
}

void fried_renderer_fill_textured_triangles(int rendererId, int, const fried_real *points, const fried_real *, const int *argbColors, int triangleCount)
{
    fried_renderer_fill_triangles(rendererId, points, argbColors, triangleCount);
}
