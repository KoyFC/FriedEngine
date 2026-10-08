#include "platform/application.h"

#include "last_error.h"

// gint brings the calculator up before main() and takes it down after, so
// there is nothing left to initialize here. There is no audio output to open:
// the silent device is the only one, and the engine opens it when the real one
// fails.

int fried_application_init()
{
    return 0;
}

int fried_application_open_audio_device()
{
    fried_set_last_error("The fx-CG50 has no audio output");
    return -1;
}

int fried_application_open_silent_audio()
{
    return 0;
}

void fried_application_shutdown()
{
}
