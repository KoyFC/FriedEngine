#include "platform/application.h"
#include "platform/gamepad.h"

#include <SDL.h>
#include <SDL_image.h>
#include <SDL_mixer.h>
#include <SDL_ttf.h>

namespace
{
#if defined(__vita__) || defined(__SWITCH__)
    // Both consoles mix at 48 kHz natively, so anything else resamples.
    constexpr int s_audioFrequency = 48000;
    constexpr int s_audioChunkSize = 1024;
#else
    constexpr int s_audioFrequency = 44100;
    constexpr int s_audioChunkSize = 2048;
#endif
    constexpr int s_audioChannels = 2;
}

int fried_application_init()
{
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_GAMECONTROLLER) != 0)
    {
        return -1;
    }

    if ((IMG_Init(IMG_INIT_PNG) & IMG_INIT_PNG) == 0)
    {
        SDL_Quit();
        return -1;
    }

    if (TTF_Init() != 0)
    {
        IMG_Quit();
        SDL_Quit();
        return -1;
    }

    if (Mix_OpenAudio(s_audioFrequency, MIX_DEFAULT_FORMAT, s_audioChannels, s_audioChunkSize) != 0)
    {
        TTF_Quit();
        IMG_Quit();
        SDL_Quit();
        return -1;
    }

    fried_gamepad_init();

    return 0;
}

void fried_application_shutdown()
{
    fried_gamepad_shutdown();
    Mix_CloseAudio();
    Mix_Quit();
    TTF_Quit();
    IMG_Quit();
    SDL_Quit();
}
