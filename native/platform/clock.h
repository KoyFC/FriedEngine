#pragma once

#include <stdint.h>

// A clock that counts whole microseconds in an int that wraps about every 71 minutes, so a duration is worked out from two readings with no floating point and no number so large that a float cannot tell a frame from the next.
extern "C" int fried_clock_micros(void);

// The microseconds from one reading to a later one, right across a wrap, for a span of up to 35 minutes.
static inline int fried_clock_difference(int later, int earlier)
{
    return (int)((uint32_t)later - (uint32_t)earlier);
}
