// What hxcpp needs from the platform beneath it that calico and newlib leave
// out, linked into every DS game.

#include <calico/arm/common.h>
#include <calico/system/tick.h>

#include <stdint.h>
#include <sys/time.h>
#include <time.h>

namespace
{
    bool s_clockAnchored = false;
    time_t s_anchorSeconds = 0;
    uint64_t s_anchorTicks = 0;
}

extern "C"
{
    // calico's gettimeofday() has only the RTC's whole seconds, so every
    // frame but one a second would last no time at all. The system tick
    // counter supplies the rest, anchored to the RTC's time the first time
    // the clock is read; time() still reads the RTC through newlib. calico
    // only starts the counter once something schedules a task on it.
    int gettimeofday(struct timeval *now, void *)
    {
        if (!s_clockAnchored)
        {
            tickInit();
            s_anchorSeconds = time(nullptr);
            s_anchorTicks = tickGetCount();
            s_clockAnchored = true;
        }

        uint64_t elapsed = tickGetCount() - s_anchorTicks;
        now->tv_sec = s_anchorSeconds + (time_t)(elapsed / TICK_FREQ);
        now->tv_usec = (long)((elapsed % TICK_FREQ) * 1000000 / TICK_FREQ);
        return 0;
    }

    // The ARM946E-S is ARMv5TE, which has no exclusive loads and stores, so
    // GCC calls out for every atomic hxcpp's garbage collector uses and
    // devkitARM ships no libatomic to answer. Interrupts are masked around
    // each operation, which is what makes a read-modify-write indivisible on
    // a single core.
    bool __atomic_compare_exchange_4(volatile void *target, void *expected, unsigned int desired, bool, int, int)
    {
        ArmIrqState state = armIrqLockByPsr();
        volatile unsigned int *value = (volatile unsigned int *)target;
        unsigned int *expectedValue = (unsigned int *)expected;
        bool exchanged = *value == *expectedValue;
        if (exchanged)
        {
            *value = desired;
        }
        else
        {
            *expectedValue = *value;
        }
        armIrqUnlockByPsr(state);
        return exchanged;
    }

    unsigned int __atomic_fetch_add_4(volatile void *target, unsigned int amount, int)
    {
        ArmIrqState state = armIrqLockByPsr();
        volatile unsigned int *value = (volatile unsigned int *)target;
        unsigned int previous = *value;
        *value = previous + amount;
        armIrqUnlockByPsr(state);
        return previous;
    }

    unsigned int __atomic_fetch_sub_4(volatile void *target, unsigned int amount, int)
    {
        ArmIrqState state = armIrqLockByPsr();
        volatile unsigned int *value = (volatile unsigned int *)target;
        unsigned int previous = *value;
        *value = previous - amount;
        armIrqUnlockByPsr(state);
        return previous;
    }
}
