#pragma once

// The type of the numbers in arrays that cross from Haxe, which is what Haxe's Float is in the C++ it generates: a float on a build with HXCPP_FLOAT32 (CMake's FRIED_FLOAT32, on for the DS), and a double everywhere else.
#if defined(FRIED_FLOAT32)
typedef float fried_real;
#else
typedef double fried_real;
#endif
