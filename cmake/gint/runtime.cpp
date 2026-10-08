// What hxcpp needs from the platform beneath it that gint and fxlibc leave
// out, linked into every fx-CG50 game.

#include "posix_extras.h"

#include <sys/time.h>
#include <sys/times.h>
#include <termios.h>
#include <xlocale.h>

#include <errno.h>
#include <fxlibc/printf.h>
#include <gint/clock.h>
#include <gint/timer.h>
#include <stdint.h>
#include <string.h>

namespace
{
    // fxlibc's clock() counts the RTC's 128 ticks a second, so a frame's
    // length would come out 7.8 ms at a time. A TMU counting milliseconds is
    // what Sys.time() reads instead, and clock() only stands in until it runs.
    // It pauses while the OS has the calculator, for a world switch or the
    // main menu.
    volatile uint64_t s_milliseconds = 0;
    bool s_millisecondTimerRunning = false;

    int countMillisecond()
    {
        s_milliseconds = s_milliseconds + 1;
        return TIMER_CONTINUE;
    }

    void startMillisecondTimer()
    {
        int timer = timer_configure(TIMER_TMU, 1000, GINT_CALL(countMillisecond));
        if (timer < 0)
        {
            return;
        }
        timer_start(timer);
        s_millisecondTimerRunning = true;
    }

    // The interrupt can land between the two halves of a 64-bit read.
    uint64_t readMilliseconds()
    {
        uint64_t first, second;
        do
        {
            first = s_milliseconds;
            second = s_milliseconds;
        } while (first != second);
        return first;
    }
}

extern "C"
{
    // hxcpp sizes its garbage collector from these. Its defaults ask for 8 MB
    // of working memory, ten times what the calculator has.
    char *getenv(const char *name)
    {
        if (!strcmp(name, "HXCPP_MINIMUM_WORKING_MEMORY"))
        {
            return (char *)"393216";
        }
        if (!strcmp(name, "HXCPP_MINIMUM_FREE_SPACE"))
        {
            return (char *)"98304";
        }
        return nullptr;
    }

    char *environ_entries[] = {nullptr};
    char **environ = environ_entries;

    int setenv(const char *, const char *, int)
    {
        errno = ENOSYS;
        return -1;
    }

    int unsetenv(const char *)
    {
        errno = ENOSYS;
        return -1;
    }

    int getpid()
    {
        return 1;
    }

    int system(const char *)
    {
        return -1;
    }

    char *getcwd(char *, size_t)
    {
        errno = ENOSYS;
        return nullptr;
    }

    int chdir(const char *)
    {
        errno = ENOSYS;
        return -1;
    }

    char *realpath(const char *, char *)
    {
        errno = ENOSYS;
        return nullptr;
    }

    ssize_t readlink(const char *, char *, size_t)
    {
        errno = ENOSYS;
        return -1;
    }

    int gettimeofday(struct timeval *now, void *)
    {
        if (!s_millisecondTimerRunning)
        {
            clock_t ticks = clock();
            now->tv_sec = (time_t)(ticks / CLOCKS_PER_SEC);
            now->tv_usec = (long)((ticks % CLOCKS_PER_SEC) * 1000000 / CLOCKS_PER_SEC);
            return 0;
        }

        uint64_t milliseconds = readMilliseconds();
        now->tv_sec = (time_t)(milliseconds / 1000);
        now->tv_usec = (long)(milliseconds % 1000) * 1000;
        return 0;
    }

    clock_t times(struct tms *buffer)
    {
        clock_t now = clock();
        if (buffer)
        {
            buffer->tms_utime = now;
            buffer->tms_stime = 0;
            buffer->tms_cutime = 0;
            buffer->tms_cstime = 0;
        }
        return now;
    }

    int nanosleep(const struct timespec *duration, struct timespec *remaining)
    {
        sleep_us((uint64_t)duration->tv_sec * 1000000 + duration->tv_nsec / 1000);
        if (remaining)
        {
            remaining->tv_sec = 0;
            remaining->tv_nsec = 0;
        }
        return 0;
    }

    int tcgetattr(int, struct termios *)
    {
        errno = ENOSYS;
        return -1;
    }

    int tcsetattr(int, int, const struct termios *)
    {
        errno = ENOSYS;
        return -1;
    }

    void cfmakeraw(struct termios *)
    {
    }

    locale_t newlocale(int, const char *, locale_t)
    {
        return nullptr;
    }

    locale_t uselocale(locale_t)
    {
        return LC_GLOBAL_LOCALE;
    }

    void freelocale(locale_t)
    {
    }

    // The SH4 has no compare-and-swap, so GCC calls out for these. With one
    // thread a plain read-modify-write cannot be interrupted by another.
    bool __atomic_compare_exchange_4(volatile void *target, void *expected, unsigned int desired, bool, int, int)
    {
        volatile unsigned int *value = (volatile unsigned int *)target;
        unsigned int *expectedValue = (unsigned int *)expected;
        if (*value == *expectedValue)
        {
            *value = desired;
            return true;
        }
        *expectedValue = *value;
        return false;
    }

    unsigned int __atomic_fetch_add_4(volatile void *target, unsigned int amount, int)
    {
        volatile unsigned int *value = (volatile unsigned int *)target;
        unsigned int previous = *value;
        *value = previous + amount;
        return previous;
    }

    unsigned int __atomic_fetch_sub_4(volatile void *target, unsigned int amount, int)
    {
        volatile unsigned int *value = (volatile unsigned int *)target;
        unsigned int previous = *value;
        *value = previous - amount;
        return previous;
    }

    // Bounds of the unwind tables, kept by the linker script CG50.cmake writes.
    extern char eh_frame_start[];
    void __register_frame_info(const void *begin, void *object);
}

namespace
{
    // libgcc's struct object, with room to spare.
    void *s_unwindObject[8];

    // gint links no crtbegin.o, which is what would otherwise hand the unwind
    // tables to libgcc; without them every throw ends in std::terminate().
    // fxlibc leaves floating point out of printf() unless asked, and hxcpp
    // turns a Float into text with "%.15g".
    __attribute__((constructor)) void initializeRuntime()
    {
        __register_frame_info(eh_frame_start, s_unwindObject);
        __printf_enable_fp();
        startMillisecondTimer();
    }
}
