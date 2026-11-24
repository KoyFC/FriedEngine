#include "platform/clock.h"

#include <sys/time.h>

extern "C" int fried_clock_micros(void)
{
    timeval now;
    gettimeofday(&now, nullptr);
    return (int)(uint32_t)((uint64_t)now.tv_sec * 1000000u + (uint64_t)now.tv_usec);
}
