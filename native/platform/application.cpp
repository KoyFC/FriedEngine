#include "platform/application.h"
#include "platform/gamepad.h"
#include "last_error.h"

#include <SDL.h>
#include <SDL_image.h>
#include <SDL_mixer.h>
#include <SDL_ttf.h>

#ifdef __3DS__
#include <3ds.h>
#endif

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
#ifdef __3DS__
    // SDL2main would ask for the New 3DS's clock and cache, but hxcpp brings its own main().
    osSetSpeedupEnable(true);
#endif

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER) != 0)
    {
        fried_capture_sdl_error();
        return -1;
    }

    // Every cleanup call below would overwrite the error, so it is captured first.
    if ((IMG_Init(IMG_INIT_PNG) & IMG_INIT_PNG) == 0)
    {
        fried_capture_sdl_error();
        SDL_Quit();
        return -1;
    }

    if (TTF_Init() != 0)
    {
        fried_capture_sdl_error();
        IMG_Quit();
        SDL_Quit();
        return -1;
    }

    fried_gamepad_init();

    return 0;
}

int fried_application_open_audio_device()
{
    if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0)
    {
        fried_capture_sdl_error();
        return -1;
    }

    if (Mix_OpenAudio(s_audioFrequency, MIX_DEFAULT_FORMAT, s_audioChannels, s_audioChunkSize) != 0)
    {
        fried_capture_sdl_error();
        SDL_QuitSubSystem(SDL_INIT_AUDIO);
        return -1;
    }

    return 0;
}

int fried_application_open_silent_audio()
{
    SDL_SetHintWithPriority(SDL_HINT_AUDIODRIVER, "dummy", SDL_HINT_OVERRIDE);
    return fried_application_open_audio_device();
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
