#include "math/real.h"
#include "graphics/renderer.h"


bool fried_renderer_draws_textured_triangles(int)
{
    return false;
}

void fried_renderer_fill_textured_triangles(int rendererId, int, const fried_real *points, const fried_real *, const int *argbColors, int triangleCount)
{
    fried_renderer_fill_triangles(rendererId, points, argbColors, triangleCount);
}
