#include "scene/transform2d.h"

#include <cmath>
#include <vector>

#include "math/fixed_point.h"

namespace
{
    constexpr double s_degreesToRadians = 3.14159265358979323846 / 180.0;

    struct Slot
    {
        double m_local[5];
        double m_world[5];
        int m_parent;
    };

    std::vector<Slot> s_slots;
    std::vector<int> s_freeSlots;
    std::vector<int> s_releasedSlots;
}

extern "C"
{
    int fried_transform2d_create(void)
    {
        Slot fresh = {{0.0, 0.0, 0.0, 1.0, 1.0}, {0.0, 0.0, 0.0, 1.0, 1.0}, -1};
        if (!s_freeSlots.empty())
        {
            int slot = s_freeSlots.back();
            s_freeSlots.pop_back();
            s_slots[slot] = fresh;
            return slot;
        }
        s_slots.push_back(fresh);
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
        double *local = s_slots[slot].m_local;
        local[0] = x;
        local[1] = y;
        local[2] = rotation;
        local[3] = scaleX;
        local[4] = scaleY;
    }

    void fried_transform2d_set_x(int slot, double value)
    {
        s_slots[slot].m_local[0] = value;
    }

    void fried_transform2d_set_y(int slot, double value)
    {
        s_slots[slot].m_local[1] = value;
    }

    void fried_transform2d_set_rotation(int slot, double degrees)
    {
        s_slots[slot].m_local[2] = degrees;
    }

    void fried_transform2d_set_scale_x(int slot, double value)
    {
        s_slots[slot].m_local[3] = value;
    }

    void fried_transform2d_set_scale_y(int slot, double value)
    {
        s_slots[slot].m_local[4] = value;
    }

    void fried_transform2d_update(int slot)
    {
        Slot &self = s_slots[slot];
        const double *local = self.m_local;
        double *world = self.m_world;
        if (self.m_parent < 0)
        {
            for (int index = 0; index < 5; ++index)
            {
                world[index] = local[index];
            }
        }
        else
        {
            const double *parent = s_slots[self.m_parent].m_world;
            if (parent[2] == 0.0 && parent[3] == 1.0 && parent[4] == 1.0)
            {
                world[0] = parent[0] + local[0];
                world[1] = parent[1] + local[1];
            }
            else
            {
                double scaledX = local[0] * parent[3];
                double scaledY = local[1] * parent[4];
                if (parent[2] != 0.0)
                {
                    double radians = parent[2] * s_degreesToRadians;
                    double cosine = std::cos(radians);
                    double sine = std::sin(radians);
                    world[0] = parent[0] + scaledX * cosine - scaledY * sine;
                    world[1] = parent[1] + scaledX * sine + scaledY * cosine;
                }
                else
                {
                    world[0] = parent[0] + scaledX;
                    world[1] = parent[1] + scaledY;
                }
            }
            world[2] = parent[2] + local[2];
            world[3] = parent[3] * local[3];
            world[4] = parent[4] * local[4];
        }
    }

    void fried_transform2d_bounds(int slot, double width, double height, int *out)
    {
        const double *world = s_slots[slot].m_world;
        out[0] = fried_bounds_low(world[0], width, world[3]);
        out[1] = fried_bounds_low(world[1], height, world[4]);
        out[2] = fried_bounds_high(world[0], width, world[3]);
        out[3] = fried_bounds_high(world[1], height, world[4]);
    }

    void fried_transform2d_set_world(int slot, const double *values)
    {
        double *world = s_slots[slot].m_world;
        for (int index = 0; index < 5; ++index)
        {
            world[index] = values[index];
        }
    }

    void fried_transform2d_read_world(int slot, double *out)
    {
        const double *world = s_slots[slot].m_world;
        for (int index = 0; index < 5; ++index)
        {
            out[index] = world[index];
        }
    }
}
