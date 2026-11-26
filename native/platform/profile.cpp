#include "platform/profile.h"

#include <stdlib.h>

#include "platform/clock.h"

namespace
{
    constexpr int s_sections = 8;
    constexpr int s_capacity = 240;

    int s_totals[s_sections];
    int *s_ring = nullptr;
    int s_head = 0;
    int s_count = 0;
}

extern "C"
{
    int fried_profile_tick(void)
    {
        return fried_clock_micros();
    }

    void fried_profile_add(int section, int start)
    {
        s_totals[section] += fried_clock_difference(fried_clock_micros(), start);
    }

    void fried_profile_frame(void)
    {
        if (s_ring == nullptr)
        {
            s_ring = (int *)calloc(s_capacity * s_sections, sizeof(int));
            if (s_ring == nullptr)
            {
                return;
            }
        }
        int *slot = s_ring + s_head * s_sections;
        for (int section = 0; section < s_sections; ++section)
        {
            slot[section] = s_totals[section];
            s_totals[section] = 0;
        }
        s_head = (s_head + 1) % s_capacity;
        if (s_count < s_capacity)
        {
            ++s_count;
        }
    }

    int fried_profile_frames(void)
    {
        return s_count;
    }

    int fried_profile_capacity(void)
    {
        return s_capacity;
    }

    int fried_profile_sections(void)
    {
        return s_sections;
    }

    int fried_profile_sample(int back, int section)
    {
        if (back < 0 || back >= s_count || section < 0 || section >= s_sections)
        {
            return 0;
        }
        int index = (s_head - 1 - back + s_capacity * 2) % s_capacity;
        return s_ring[index * s_sections + section];
    }
}
