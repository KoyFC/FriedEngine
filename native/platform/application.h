#pragma once

extern "C" int fried_application_init();
extern "C" int fried_application_open_audio_device();
extern "C" int fried_application_open_silent_audio();
extern "C" void fried_application_shutdown();

// Returns 1 once it has waited for the host's next frame, 0 when the host leaves pacing to the caller.
extern "C" int fried_application_wait_for_host_frame();

// The bytes the heap has left on the DS, where memory is what a game runs out of first, and -1 on a platform that does not count.
#if defined(__NDS__)
extern "C" int fried_application_free_memory();
#else
extern "C" inline int fried_application_free_memory()
{
    return -1;
}
#endif

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
#elif defined(__ANDROID__)
    return "android";
#else
    return "pc";
#endif
}
