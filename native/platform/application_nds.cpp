#include "platform/application.h"

#include "last_error.h"
#include "platform/console_nds.h"

#include <nds.h>

#include <cstdio>
#include <cstdlib>

// The bottom screen is the text console that standard output prints to, so
// the log and a crash report are read there, unless a game opens a window on
// it (platform/console_nds.h). There is no audio output to open: the silent
// device is the only one, and the engine opens it when the real one fails.

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

int fried_application_open_audio_device()
{
    fried_set_last_error("The engine has no audio output on the DS");
    return -1;
}

int fried_application_open_silent_audio()
{
    return 0;
}

void fried_application_shutdown()
{
}

int fried_application_wait_for_host_frame()
{
    return 0;
}
