#pragma once

#include <cstdint>
#include <cstring>

// Numbers as integers, worked out from the bits of a double rather than with
// a call into software floating point, which is what every operation on a
// double is on a CPU without a floating point unit, such as the DS's.

// A number times 2 to the power of fractionBits, rounded toward zero, or down
// when isFloor is set. It saturates far beyond anything a game is placed at.
static inline int64_t fried_fixed_convert(double value, int fractionBits, bool isFloor)
{
    uint64_t bits;
    std::memcpy(&bits, &value, sizeof bits);
    int exponent = (int)((bits >> 52) & 0x7ff);
    if (exponent == 0)
    {
        return 0;
    }
    int64_t mantissa = (int64_t)((bits & 0xfffffffffffffull) | 0x10000000000000ull);
    int shift = exponent - 1075 + fractionBits;
    int64_t magnitude;
    bool isInexact = false;
    if (shift >= 10)
    {
        magnitude = INT64_MAX / 2;
    }
    else if (shift >= 0)
    {
        magnitude = mantissa << shift;
    }
    else if (shift > -64)
    {
        magnitude = mantissa >> -shift;
        isInexact = ((uint64_t)mantissa & ((1ull << -shift) - 1)) != 0;
    }
    else
    {
        magnitude = 0;
        isInexact = true;
    }
    if ((bits >> 63) == 0)
    {
        return magnitude;
    }
    return isFloor && isInexact ? -magnitude - 1 : -magnitude;
}

static inline int64_t fried_to_fixed(double value, int fractionBits)
{
    return fried_fixed_convert(value, fractionBits, false);
}

// The double a fixed number stands for, built from its bits.
static inline double fried_from_fixed(int64_t value, int fractionBits)
{
    if (value == 0)
    {
        return 0.0;
    }
    uint64_t sign = 0;
    uint64_t magnitude = (uint64_t)value;
    if (value < 0)
    {
        sign = 1ull << 63;
        magnitude = (uint64_t)(-value);
    }
    int top = 63 - __builtin_clzll(magnitude);
    uint64_t mantissa = top >= 52 ? magnitude >> (top - 52) : magnitude << (52 - top);
    uint64_t exponent = (uint64_t)(top - fractionBits + 1023);
    uint64_t bits = sign | (exponent << 52) | (mantissa & 0xfffffffffffffull);
    double result;
    std::memcpy(&result, &bits, sizeof result);
    return result;
}

// Where a Collider's box is, in 20.12: the pixel is 4096 units, which is a
// finer grid than anything is drawn on, and the range is a quarter of a
// million pixels either way, past which a position saturates. Rounding down
// keeps the order of two numbers, and with it what overlaps and what only
// touches.
static const int FRIED_BOUNDS_BITS = 12;
static const int FRIED_BOUNDS_LIMIT = 0x3fffffff;

static inline int fried_bounds_clamp(int64_t value)
{
    return value > FRIED_BOUNDS_LIMIT ? FRIED_BOUNDS_LIMIT : (value < -FRIED_BOUNDS_LIMIT ? -FRIED_BOUNDS_LIMIT : (int)value);
}

static inline int fried_bounds_point(double value)
{
    return fried_bounds_clamp(fried_fixed_convert(value, FRIED_BOUNDS_BITS, true));
}

static inline int64_t fried_bounds_extent(double size, double scale)
{
    return (fried_fixed_convert(size, FRIED_BOUNDS_BITS, true) * fried_fixed_convert(scale, FRIED_BOUNDS_BITS, true)) >> FRIED_BOUNDS_BITS;
}

// The near edge of a box that starts at origin and is size times scale long,
// which runs backward when either is negative.
static inline int fried_bounds_low(double origin, double size, double scale)
{
    int64_t extent = fried_bounds_extent(size, scale);
    int64_t start = fried_fixed_convert(origin, FRIED_BOUNDS_BITS, true);
    return fried_bounds_clamp(extent < 0 ? start + extent : start);
}

static inline int fried_bounds_high(double origin, double size, double scale)
{
    int64_t extent = fried_bounds_extent(size, scale);
    int64_t start = fried_fixed_convert(origin, FRIED_BOUNDS_BITS, true);
    return fried_bounds_clamp(extent < 0 ? start : start + extent);
}
