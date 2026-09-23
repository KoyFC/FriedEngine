#include "input.h"

#include <SDL.h>
#include <cstring>

namespace
{
    Uint8 s_previousState[SDL_NUM_SCANCODES] = {};
}

int fried_input_is_key_pressed(int scancode)
{
    if (scancode < 0 || scancode >= SDL_NUM_SCANCODES)
    {
        return 0;
    }
    return SDL_GetKeyboardState(nullptr)[scancode];
}

int fried_input_is_key_down(int scancode)
{
    if (scancode < 0 || scancode >= SDL_NUM_SCANCODES)
    {
        return 0;
    }
    return SDL_GetKeyboardState(nullptr)[scancode] && !s_previousState[scancode];
}

int fried_input_is_key_released(int scancode)
{
    if (scancode < 0 || scancode >= SDL_NUM_SCANCODES)
    {
        return 0;
    }
    return !SDL_GetKeyboardState(nullptr)[scancode] && s_previousState[scancode];
}

void fried_input_end_frame()
{
    std::memcpy(s_previousState, SDL_GetKeyboardState(nullptr), sizeof(s_previousState));
}
