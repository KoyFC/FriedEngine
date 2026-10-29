#include "last_error.h"

#if !defined(TARGET_FXCG50) && !defined(__NDS__)
#include <SDL.h>
#endif

#include <cstdio>

namespace
{
    char s_lastError[256] = "";
}

const char *fried_last_error()
{
    return s_lastError;
}

#if !defined(TARGET_FXCG50) && !defined(__NDS__)
void fried_capture_sdl_error()
{
    fried_set_last_error(SDL_GetError());
}
#endif

void fried_set_last_error(const char *message)
{
    if (!message)
    {
        s_lastError[0] = '\0';
        return;
    }

    std::snprintf(s_lastError, sizeof(s_lastError), "%s", message);
}
