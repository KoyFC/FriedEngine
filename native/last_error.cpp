#include "last_error.h"

#include <SDL.h>

#include <cstdio>

namespace
{
    char s_lastError[256] = "";
}

const char *fried_last_error()
{
    return s_lastError;
}

void fried_capture_sdl_error()
{
    fried_set_last_error(SDL_GetError());
}

void fried_set_last_error(const char *message)
{
    if (!message)
    {
        s_lastError[0] = '\0';
        return;
    }

    std::snprintf(s_lastError, sizeof(s_lastError), "%s", message);
}
