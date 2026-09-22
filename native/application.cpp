#include "application.h"

#include <SDL.h>

int fried_application_init()
{
    return SDL_Init(SDL_INIT_VIDEO) == 0 ? 0 : -1;
}

void fried_application_shutdown()
{
    SDL_Quit();
}
