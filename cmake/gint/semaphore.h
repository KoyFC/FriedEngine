// With one thread nothing can post while another waits, so a wait succeeds
// only on what was already posted.

#pragma once

#include <time.h>

typedef int sem_t;

static inline int sem_init(sem_t *semaphore, int, unsigned value)
{
    *semaphore = (int)value;
    return 0;
}

static inline int sem_destroy(sem_t *) { return 0; }

static inline int sem_post(sem_t *semaphore)
{
    ++*semaphore;
    return 0;
}

static inline int sem_trywait(sem_t *semaphore)
{
    if (*semaphore <= 0)
    {
        return -1;
    }
    --*semaphore;
    return 0;
}

static inline int sem_wait(sem_t *semaphore) { return sem_trywait(semaphore); }
static inline int sem_timedwait(sem_t *semaphore, const struct timespec *) { return sem_trywait(semaphore); }
