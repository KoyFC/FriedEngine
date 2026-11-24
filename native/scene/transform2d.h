#pragma once

#include <cstdint>

extern "C"
{
    int fried_transform2d_create(void);
    // Every number the store takes or gives is a float, which is what the Haxe side keeps a 2D position, size or angle in.
    // The slot stays readable until the next fried_transform2d_collect(), as records queued this frame may still name it.
    void fried_transform2d_release(int slot);
    void fried_transform2d_collect(void);
    void fried_transform2d_set_parent(int slot, int parentSlot);
    void fried_transform2d_set_local(int slot, float x, float y, float rotation, float scaleX, float scaleY);
    void fried_transform2d_set_x(int slot, float value);
    void fried_transform2d_set_y(int slot, float value);
    void fried_transform2d_set_rotation(int slot, float degrees);
    void fried_transform2d_set_scale_x(int slot, float value);
    void fried_transform2d_set_scale_y(int slot, float value);
    // Works the world values out from the locals and the parent slot's world values, which the caller made current first, and keeps them.
    void fried_transform2d_update(int slot);
    // A Collider's box in world space as four integers in 20.12 (left, top, right, bottom), from the slot's world values and the collider's own width and height, as math/fixed_point.h works them out.
    void fried_transform2d_bounds(int slot, float width, float height, int *out);
    // For a node placed by Haxe, whose children may still be worked out here.
    void fried_transform2d_set_world(int slot, const float *values);
    void fried_transform2d_read_world(int slot, float *out);
}

#ifdef __NDS__
struct FriedTransform2DFixed
{
    int32_t m_x;        // 16.16
    int32_t m_y;        // 16.16
    int32_t m_rotation; // degrees in 20.12, as toAngle takes them
    int64_t m_scaleX;   // 32 fraction bits, as a scaled texture record uses them
    int64_t m_scaleY;
};

const FriedTransform2DFixed *fried_transform2d_world_fixed(int slot);
#endif
