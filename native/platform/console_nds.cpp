#include "platform/console_nds.h"

#include <nds.h>
#include <sys/iosupport.h>

#include <cstring>

namespace
{
    // About the 24 lines of 32 characters the console shows.
    constexpr size_t s_keptBytes = 1024;

    char s_kept[s_keptBytes];
    size_t s_keptEnd = 0;
    bool s_keptWrapped = false;

    const devoptab_t *s_consoleOutput = nullptr;
    bool s_hasScreen = false;

    void keep(const char *text, size_t length)
    {
        for (size_t index = 0; index < length; ++index)
        {
            s_kept[s_keptEnd] = text[index];
            s_keptEnd = (s_keptEnd + 1) % s_keptBytes;
            s_keptWrapped = s_keptWrapped || s_keptEnd == 0;
        }
    }

    ssize_t writeAndKeep(struct _reent *reent, void *fd, const char *text, size_t length)
    {
        keep(text, length);
        if (s_hasScreen && s_consoleOutput && s_consoleOutput->write_r)
        {
            s_consoleOutput->write_r(reent, fd, text, length);
        }
        return (ssize_t)length;
    }

    devoptab_t s_output = {"stdout", 0, nullptr, nullptr, writeAndKeep};

    // consoleDemoInit() points both streams at the console each time it runs.
    void showConsole()
    {
        consoleDemoInit();
        if (devoptab_list[STD_OUT] != &s_output)
        {
            s_consoleOutput = devoptab_list[STD_OUT];
        }
        devoptab_list[STD_OUT] = &s_output;
        devoptab_list[STD_ERR] = &s_output;
        s_hasScreen = true;
    }

    // From the first whole line kept, so a line cut by the buffer's start is
    // left out.
    void replayKept()
    {
        if (!s_consoleOutput || !s_consoleOutput->write_r)
        {
            return;
        }
        if (!s_keptWrapped)
        {
            s_consoleOutput->write_r(_REENT, nullptr, s_kept, s_keptEnd);
            return;
        }
        char ordered[s_keptBytes];
        size_t tail = s_keptBytes - s_keptEnd;
        std::memcpy(ordered, s_kept + s_keptEnd, tail);
        std::memcpy(ordered + tail, s_kept, s_keptEnd);
        const char *firstLine = (const char *)std::memchr(ordered, '\n', s_keptBytes);
        size_t start = firstLine ? (size_t)(firstLine - ordered) + 1 : 0;
        s_consoleOutput->write_r(_REENT, nullptr, ordered + start, s_keptBytes - start);
    }
}

void fried_console_start()
{
    showConsole();
}

void fried_console_release_screen()
{
    s_hasScreen = false;
}

void fried_console_reclaim_screen()
{
    if (s_hasScreen)
    {
        return;
    }
    showConsole();
    replayKept();
}
