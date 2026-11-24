#include "platform/clock.h"

#include <calico/system/tick.h>

// Read from the system tick counter, which runtime.cpp starts, and not through gettimeofday(), which would divide twice to give seconds and microseconds and be divided back.
extern "C" uint64_t fried_nds_tick_count(void);

extern "C" int fried_clock_micros(void)
{
    return (int)(uint32_t)((fried_nds_tick_count() * 1000000ull) / TICK_FREQ);
}
