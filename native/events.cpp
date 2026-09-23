#include "events.h"
#include "mouse.h"

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
        else if (event.type == SDL_MOUSEWHEEL)
        {
            int x = event.wheel.x;
            int y = event.wheel.y;
            if (event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED)
            {
                x = -x;
                y = -y;
            }
            fried_mouse_report_wheel(x, y);
        }
    }
    return quitRequested;
}
