#include "events.h"

#include <SDL.h>

int fried_events_pump()
{
    SDL_Event event;
    int quitRequested = 0;
    while (SDL_PollEvent(&event))
    {
        if (event.type == SDL_QUIT)
        {
            quitRequested = 1;
        }
    }
    return quitRequested;
}
