#include "graphics/renderer.h"

namespace
{
    constexpr int s_recordInts = 8;
    constexpr int s_recordDoubles = 5;

    constexpr int s_textureRecord = 0;
    constexpr int s_fillRecord = 1;
    constexpr int s_outlineRecord = 2;
    constexpr int s_cameraRecord = 3;
}

// The same arithmetic, in the same order, that the draw queue did when it placed each command itself.
void fried_draw_batch_with_calls(int rendererId, const int *ints, const double *doubles, int count)
{
    double halfWidth = fried_renderer_get_width(rendererId) / 2.0;
    double halfHeight = fried_renderer_get_height(rendererId) / 2.0;
    bool hasCamera = false;
    double zoom = 1.0;
    double offsetX = 0.0;
    double offsetY = 0.0;

    for (int index = 0; index < count; ++index)
    {
        const int *record = ints + index * s_recordInts;
        const double *values = doubles + index * s_recordDoubles;
        int kind = record[0];
        if (kind == s_cameraRecord)
        {
            hasCamera = record[7] != 0;
            if (hasCamera)
            {
                zoom = values[0];
                offsetX = halfWidth - values[1] * zoom;
                offsetY = halfHeight - values[2] * zoom;
            }
            continue;
        }

        double x = values[0];
        double y = values[1];
        double width = values[2];
        double height = values[3];
        if (hasCamera)
        {
            x = x * zoom + offsetX;
            y = y * zoom + offsetY;
            width = width * zoom;
            height = height * zoom;
        }

        if (kind == s_textureRecord)
        {
            fried_renderer_draw_texture_ex(rendererId, record[1], record[2], record[3], record[4], record[5], (float)x, (float)y, (float)width, (float)height, values[4], record[6]);
            continue;
        }
        int color = record[1];
        fried_renderer_set_draw_color(rendererId, (color >> 16) & 0xff, (color >> 8) & 0xff, color & 0xff, (color >> 24) & 0xff);
        if (kind == s_fillRecord)
        {
            fried_renderer_fill_rect(rendererId, (float)x, (float)y, (float)width, (float)height);
        }
        else if (kind == s_outlineRecord)
        {
            fried_renderer_draw_rect(rendererId, (float)x, (float)y, (float)width, (float)height);
        }
    }
}

#ifndef __NDS__
void fried_renderer_draw_batch(int rendererId, const int *ints, const double *doubles, int count)
{
    fried_draw_batch_with_calls(rendererId, ints, doubles, count);
}
#endif
