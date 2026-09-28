#pragma once

extern "C"
{
    const char *fried_last_error();
}

// Every failure that reaches Haxe as a thrown error sets one of these first,
// so the reported message is always the one that belongs to that failure.
void fried_capture_sdl_error();
void fried_set_last_error(const char *message);
