// Forced in ahead of the Haxe code of a DS game built for size. hxcpp reads a flags word in front of every string literal, and -Os stops GCC aligning literals to a word, so on the ARM9 the load came back rotated. Each literal is kept in a word aligned array of its own instead.
#pragma once
#include <hxcpp.h>

#undef HX_HCSTRING
#undef HX_
#undef HX_STRINGI
#define FRIED_ALIGNED_STRING(literal, offset, length) ([]() -> ::String { alignas(4) static const char fried_literal[] = literal; return ::String(const_cast<char *>(fried_literal) + offset, length); }())
#define HX_HCSTRING(s,h0,h1,h2,h3) FRIED_ALIGNED_STRING(h0 h1 h2 h3 "\x00\x00\x10\x80" s, 8, sizeof(s)/sizeof(char)-1)
#define HX_(s,h0,h1,h2,h3) FRIED_ALIGNED_STRING(HX_HEX_QUOTE(h0) HX_HEX_QUOTE(h1) HX_HEX_QUOTE(h2) HX_HEX_QUOTE(h3) "\x00\x00\x10\x80" s, 8, sizeof(s)/sizeof(char)-1)
#define HX_STRINGI(s,len) FRIED_ALIGNED_STRING("\x00\x00\x0\x80" s, 4, len)
