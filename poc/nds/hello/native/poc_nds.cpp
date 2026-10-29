// What the Haxe side of the DS proof of concept needs from libnds: a console
// to print to, a clock, and a view of the heap.

#include "poc_nds.h"

#include <malloc.h>
#include <nds.h>
#include <stdio.h>
#include <unistd.h>

extern "C" char *fake_heap_start;
extern "C" char *fake_heap_end;

namespace
{
    // Every line also goes to the emulator's log through the no$gba debug
    // port, since nothing reads the DS screen from the host.
    void printLine(const char *line)
    {
        printf("%s\n", line);
        nocashMessage(line);
        nocashMessage("\n");
    }

    // Runs before hxcpp's own static initialization, so a fault while the
    // runtime boots is already shown on the screen.
    __attribute__((constructor(101))) void initializeEarly()
    {
        defaultExceptionHandler();
        consoleDemoInit();
        printLine("native constructor reached");
    }
}

extern "C"
{
    void poc_nds_init()
    {
        printLine("Haxe main reached");
        cpuStartTiming(0);
    }

    void poc_nds_print(const char *text)
    {
        printLine(text);
    }

    // arena is how far the heap has grown, which newlib never gives back, so
    // it is the peak; uordblks is in use now. The heap's ceiling is whatever
    // main RAM the program and its stacks leave.
    void poc_nds_report(const char *label)
    {
        struct mallinfo info = mallinfo();
        char line[64];
        snprintf(line, sizeof(line), "%s: heap %u/%u peak %u K",
            label,
            (unsigned)info.uordblks / 1024,
            (unsigned)(fake_heap_end - fake_heap_start) / 1024,
            (unsigned)info.arena / 1024);
        printLine(line);
    }

    double poc_nds_milliseconds()
    {
        return timerTicks2usec(cpuGetTiming()) / 1000.0;
    }

    void poc_nds_wait_for_vblank()
    {
        swiWaitForVBlank();
    }
}
