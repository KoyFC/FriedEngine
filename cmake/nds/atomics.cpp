// The ARM946E-S is ARMv5TE, which has no exclusive loads and stores, so GCC
// calls out for every atomic hxcpp's garbage collector uses and devkitARM
// ships no libatomic to answer. Interrupts are masked around each operation,
// which is what makes a read-modify-write indivisible on a single core.

#include <calico/arm/common.h>

extern "C"
{
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
