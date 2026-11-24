#include "graphics/renderer.h"
#include "scene/transform2d.h"

namespace
{
    constexpr int s_recordInts = 8;
    constexpr int s_recordFloats = 5;

    constexpr int s_textureRecord = 0;
    constexpr int s_fillRecord = 1;
    constexpr int s_outlineRecord = 2;
    constexpr int s_cameraRecord = 3;
    constexpr int s_scaledTextureRecord = 4;
    constexpr int s_slotTextureRecord = 5;
}

// The same arithmetic, in the same order, that the draw queue did when it placed each command itself, in floats now that every number it is given is one. A scaled texture's size is its source's size times the scale, as Sprite worked it out before.
void fried_draw_batch_with_calls(int rendererId, const int *ints, const float *floats, int count)
{
    float halfWidth = fried_renderer_get_width(rendererId) / 2.0f;
    float halfHeight = fried_renderer_get_height(rendererId) / 2.0f;
    bool hasCamera = false;
    float zoom = 1.0f;
    float offsetX = 0.0f;
    float offsetY = 0.0f;

    for (int index = 0; index < count; ++index)
    {
        const int *record = ints + index * s_recordInts;
        const float *values = floats + index * s_recordFloats;
        int kind = record[0];
        float slotValues[5];
        if (kind == s_slotTextureRecord)
        {
            // The same numbers a scaled texture record carries: x, y, the two scales, the angle.
            float world[5];
            fried_transform2d_read_world(record[7], world);
            slotValues[0] = world[0];
            slotValues[1] = world[1];
            slotValues[2] = world[3];
            slotValues[3] = world[4];
            slotValues[4] = world[2];
            values = slotValues;
        }
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

        float x = values[0];
        float y = values[1];
        float width = values[2];
        float height = values[3];
        if (kind == s_scaledTextureRecord || kind == s_slotTextureRecord)
        {
            width = (float)record[4] * width;
            height = (float)record[5] * height;
        }
        if (hasCamera)
        {
            x = x * zoom + offsetX;
            y = y * zoom + offsetY;
            width = width * zoom;
            height = height * zoom;
        }

        if (kind == s_textureRecord || kind == s_scaledTextureRecord || kind == s_slotTextureRecord)
        {
            fried_renderer_draw_texture_ex(rendererId, record[1], record[2], record[3], record[4], record[5], x, y, width, height, values[4], record[6]);
            continue;
        }
        int color = record[1];
        fried_renderer_set_draw_color(rendererId, (color >> 16) & 0xff, (color >> 8) & 0xff, color & 0xff, (color >> 24) & 0xff);
        if (kind == s_fillRecord)
        {
            fried_renderer_fill_rect(rendererId, x, y, width, height);
        }
        else if (kind == s_outlineRecord)
        {
            fried_renderer_draw_rect(rendererId, x, y, width, height);
        }
    }
}

#ifndef __NDS__
void fried_renderer_draw_batch(int rendererId, const int *ints, const float *floats, int count)
{
    fried_draw_batch_with_calls(rendererId, ints, floats, count);
}
#endif
