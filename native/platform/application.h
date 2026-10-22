#pragma once

extern "C" int fried_application_init();
extern "C" int fried_application_open_audio_device();
extern "C" int fried_application_open_silent_audio();
extern "C" void fried_application_shutdown();

// Returns 1 once it has waited for the host's next frame, 0 when the host leaves pacing to the caller.
extern "C" int fried_application_wait_for_host_frame();
