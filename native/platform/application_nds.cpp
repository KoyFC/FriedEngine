#include "platform/application.h"

#include "last_error.h"
#include "audio/audio_nds.h"
#include "platform/console_nds.h"

#include <nds.h>

#include <cstdio>
#include <cstdlib>

// The bottom screen is the text console that standard output prints to, so
// the log and a crash report are read there, unless a game opens a window on
// it (platform/console_nds.h).

namespace
{
    // Returning from main() powers the console off, which would take the
    // reason a game stopped with it, such as an error nothing caught.
    void waitForButtonBeforePowerOff()
    {
        fried_console_reclaim_screen();
        std::printf("\nPress any button to turn the DS off\n");
        do
        {
            swiWaitForVBlank();
            scanKeys();
        } while (!keysDown());
    }
}

int fried_application_init()
{
    defaultExceptionHandler();
    fried_console_start();
    std::atexit(waitForButtonBeforePowerOff);
    return 0;
}

// The ARM7 drives the sound hardware, and the ARM9 asks it to through calico.
int fried_application_open_audio_device()
{
    soundInit();
    soundPowerOn();
    fried_sound_init();
    return 0;
}

int fried_application_open_silent_audio()
{
    fried_sound_init();
    return 0;
}

void fried_application_shutdown()
{
}

int fried_application_wait_for_host_frame()
{
    return 0;
}
