#include "scene/transform2d.h"

#include <nds.h>
#include <vector>

#include "math/fixed_point.h"

// The DS has no floating point unit, so a slot keeps its numbers in the units the renderer draws with and never does a double operation. A position is 16.16, a rotation is degrees in 20.12 and a scale has 32 bits of fraction, so a size times it is cut where the renderer cuts it.
namespace
{
    constexpr int64_t s_angleFactor = 372827;
    constexpr int64_t s_unitScale = 1ll << 32;

    struct Slot
    {
        int32_t m_localX;
        int32_t m_localY;
        int32_t m_localRotation;
        int64_t m_localScaleX;
        int64_t m_localScaleY;
        FriedTransform2DFixed m_world;
        int m_parent;
    };

    std::vector<Slot> s_slots;
    std::vector<int> s_freeSlots;
    std::vector<int> s_releasedSlots;

    const Slot s_fresh = {0, 0, 0, s_unitScale, s_unitScale, {0, 0, 0, s_unitScale, s_unitScale}, -1};
}

extern "C"
{
    int fried_transform2d_create(void)
    {
        if (!s_freeSlots.empty())
        {
            int slot = s_freeSlots.back();
            s_freeSlots.pop_back();
            s_slots[slot] = s_fresh;
            return slot;
        }
        s_slots.push_back(s_fresh);
        return (int)s_slots.size() - 1;
    }

    void fried_transform2d_release(int slot)
    {
        s_releasedSlots.push_back(slot);
    }

    void fried_transform2d_collect(void)
    {
        for (int slot : s_releasedSlots)
        {
            s_freeSlots.push_back(slot);
        }
        s_releasedSlots.clear();
    }

    void fried_transform2d_set_parent(int slot, int parentSlot)
    {
        s_slots[slot].m_parent = parentSlot;
    }

    void fried_transform2d_set_local(int slot, double x, double y, double rotation, double scaleX, double scaleY)
    {
        Slot &self = s_slots[slot];
        self.m_localX = (int32_t)fried_to_fixed(x, 16);
        self.m_localY = (int32_t)fried_to_fixed(y, 16);
        self.m_localRotation = (int32_t)fried_to_fixed(rotation, 12);
        self.m_localScaleX = fried_to_fixed(scaleX, 32);
        self.m_localScaleY = fried_to_fixed(scaleY, 32);
    }

    void fried_transform2d_set_x(int slot, double value)
    {
        s_slots[slot].m_localX = (int32_t)fried_to_fixed(value, 16);
    }

    void fried_transform2d_set_y(int slot, double value)
    {
        s_slots[slot].m_localY = (int32_t)fried_to_fixed(value, 16);
    }

    void fried_transform2d_set_rotation(int slot, double degrees)
    {
        s_slots[slot].m_localRotation = (int32_t)fried_to_fixed(degrees, 12);
    }

    void fried_transform2d_set_scale_x(int slot, double value)
    {
        s_slots[slot].m_localScaleX = fried_to_fixed(value, 32);
    }

    void fried_transform2d_set_scale_y(int slot, double value)
    {
        s_slots[slot].m_localScaleY = fried_to_fixed(value, 32);
    }

    void fried_transform2d_update(int slot)
    {
        Slot &self = s_slots[slot];
        FriedTransform2DFixed &world = self.m_world;
        if (self.m_parent < 0)
        {
            world.m_x = self.m_localX;
            world.m_y = self.m_localY;
            world.m_rotation = self.m_localRotation;
            world.m_scaleX = self.m_localScaleX;
            world.m_scaleY = self.m_localScaleY;
        }
        else
        {
            const FriedTransform2DFixed &parent = s_slots[self.m_parent].m_world;
            if (parent.m_rotation == 0 && parent.m_scaleX == s_unitScale && parent.m_scaleY == s_unitScale)
            {
                world.m_x = parent.m_x + self.m_localX;
                world.m_y = parent.m_y + self.m_localY;
            }
            else
            {
                int64_t scaledX = ((int64_t)self.m_localX * (parent.m_scaleX >> 16)) >> 16;
                int64_t scaledY = ((int64_t)self.m_localY * (parent.m_scaleY >> 16)) >> 16;
                if (parent.m_rotation != 0)
                {
                    int angle = (int)(((int64_t)parent.m_rotation * s_angleFactor) >> 24) & (DEGREES_IN_CIRCLE - 1);
                    int64_t cosine = cosLerp((s16)angle);
                    int64_t sine = sinLerp((s16)angle);
                    world.m_x = parent.m_x + (int32_t)((scaledX * cosine - scaledY * sine) >> 12);
                    world.m_y = parent.m_y + (int32_t)((scaledX * sine + scaledY * cosine) >> 12);
                }
                else
                {
                    world.m_x = parent.m_x + (int32_t)scaledX;
                    world.m_y = parent.m_y + (int32_t)scaledY;
                }
            }
            world.m_rotation = parent.m_rotation + self.m_localRotation;
            world.m_scaleX = ((parent.m_scaleX >> 16) * self.m_localScaleX) >> 16;
            world.m_scaleY = ((parent.m_scaleY >> 16) * self.m_localScaleY) >> 16;
        }
    }

    // The box in 20.12, as fried_bounds_low and fried_bounds_high work it out from doubles: the position is rounded down to a unit, and so are the size and the scale before they are multiplied.
    void fried_transform2d_bounds(int slot, double width, double height, int *out)
    {
        const FriedTransform2DFixed &world = s_slots[slot].m_world;
        int64_t extentX = (fried_fixed_convert(width, FRIED_BOUNDS_BITS, true) * (world.m_scaleX >> 20)) >> FRIED_BOUNDS_BITS;
        int64_t extentY = (fried_fixed_convert(height, FRIED_BOUNDS_BITS, true) * (world.m_scaleY >> 20)) >> FRIED_BOUNDS_BITS;
        int64_t startX = world.m_x >> 4;
        int64_t startY = world.m_y >> 4;
        out[0] = fried_bounds_clamp(extentX < 0 ? startX + extentX : startX);
        out[1] = fried_bounds_clamp(extentY < 0 ? startY + extentY : startY);
        out[2] = fried_bounds_clamp(extentX < 0 ? startX : startX + extentX);
        out[3] = fried_bounds_clamp(extentY < 0 ? startY : startY + extentY);
    }

    void fried_transform2d_set_world(int slot, const double *values)
    {
        FriedTransform2DFixed &world = s_slots[slot].m_world;
        world.m_x = (int32_t)fried_to_fixed(values[0], 16);
        world.m_y = (int32_t)fried_to_fixed(values[1], 16);
        world.m_rotation = (int32_t)fried_to_fixed(values[2], 12);
        world.m_scaleX = fried_to_fixed(values[3], 32);
        world.m_scaleY = fried_to_fixed(values[4], 32);
    }

    // Most nodes are neither turned nor scaled, and those two are then known without working the double out.
    void fried_transform2d_read_world(int slot, double *out)
    {
        const FriedTransform2DFixed &world = s_slots[slot].m_world;
        out[0] = fried_from_fixed(world.m_x, 16);
        out[1] = fried_from_fixed(world.m_y, 16);
        out[2] = world.m_rotation == 0 ? 0.0 : fried_from_fixed(world.m_rotation, 12);
        out[3] = world.m_scaleX == s_unitScale ? 1.0 : fried_from_fixed(world.m_scaleX, 32);
        out[4] = world.m_scaleY == s_unitScale ? 1.0 : fried_from_fixed(world.m_scaleY, 32);
    }
}

const FriedTransform2DFixed *fried_transform2d_world_fixed(int slot)
{
    return &s_slots[slot].m_world;
}
