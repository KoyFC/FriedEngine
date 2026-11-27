#include "platform/application.h"

#include "last_error.h"
#include "audio/audio_nds.h"
#include "platform/console_nds.h"

#include <nds.h>

#include <calico/system/tick.h>
#include <malloc.h>

#include <cstdio>
#include <cstdlib>
#include <exception>
#include <new>

// The bottom screen is the text console that standard output prints to, so
// the log and a crash report are read there, unless a game opens a window on
// it (platform/console_nds.h).

// hxcpp's collector, which the program links, and the system tick counter of cmake/nds/runtime.cpp.
void __hxcpp_collect(bool inMajor);
void __hxcpp_gc_compact();
extern "C" uint64_t fried_nds_tick_count(void);

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

    // Out of memory, or an exception nothing caught, ends here and not in exit(): neither may use the heap to say so, which is why this prints a fixed text and waits for a button without going through the atexit above.
    void stopWithMessage(const char *message)
    {
        fried_console_reclaim_screen();
        std::fputs(message, stdout);
        std::fputs("\nPress any button to turn the DS off\n", stdout);
        do
        {
            swiWaitForVBlank();
            scanKeys();
        } while (!keysDown());
        std::exit(1);
    }

    uint64_t s_lastCollectEnd = 0;
    bool s_hasCollected = false;

    // Native code asks for memory the collector is holding as garbage or as free blocks. The first time one cannot be had, the heap is collected and handed back, and the allocation is tried again; that attempt failing too, which is the handler being called again right after, is the end. Without the heap, so the number goes through a buffer of its own.
    void onOutOfMemory()
    {
        if (!s_hasCollected || fried_nds_tick_count() - s_lastCollectEnd > TICK_FREQ / 2000)
        {
            s_hasCollected = true;
            __hxcpp_collect(true);
            __hxcpp_gc_compact();
            s_lastCollectEnd = fried_nds_tick_count();
            return;
        }
        static char message[96];
        std::snprintf(message, sizeof message, "Out of memory: the game needs more than the DS has.\n%d KB were left.\n", fried_application_free_memory() / 1024);
        stopWithMessage(message);
    }

    void onTerminate()
    {
        stopWithMessage("The program stopped on an exception nothing caught.\n");
    }
}

int fried_application_free_memory()
{
    struct mallinfo info = mallinfo();
    return (int)info.fordblks + (int)(getHeapLimit() - getHeapEnd());
}

int fried_application_init()
{
    defaultExceptionHandler();
    std::set_new_handler(onOutOfMemory);
    std::set_terminate(onTerminate);
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
