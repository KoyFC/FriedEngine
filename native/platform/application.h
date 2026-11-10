#pragma once

extern "C" int fried_application_init();
extern "C" int fried_application_open_audio_device();
extern "C" int fried_application_open_silent_audio();
extern "C" void fried_application_shutdown();

// Returns 1 once it has waited for the host's next frame, 0 when the host leaves pacing to the caller.
extern "C" int fried_application_wait_for_host_frame();

// The name `project.fried` uses for the platform this was built for, "pc" for a desktop.
extern "C" inline const char *fried_application_platform_name()
{
#if defined(__vita__)
    return "vita";
#elif defined(__SWITCH__)
    return "switch";
#elif defined(__3DS__)
    return "3ds";
#elif defined(__NDS__)
    return "nds";
#elif defined(TARGET_FXCG50)
    return "cg50";
#elif defined(__EMSCRIPTEN__)
    return "web";
#else
    return "pc";
#endif
}
