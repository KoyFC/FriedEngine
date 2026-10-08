// gint runs one thread and ships no pthreads. hxcpp only needs these to guard
// state against other threads, so with one thread every lock succeeds at
// once, nothing can ever wake a wait, and no thread starts.

#pragma once

#include <stdlib.h>
#include <time.h>

typedef int pthread_t;
typedef int pthread_attr_t;
typedef int pthread_mutex_t;
typedef int pthread_mutexattr_t;
typedef int pthread_cond_t;
typedef int pthread_condattr_t;
typedef int pthread_once_t;
typedef void **pthread_key_t;

#define PTHREAD_ONCE_INIT 0
#define PTHREAD_MUTEX_RECURSIVE 1
#define PTHREAD_CREATE_DETACHED 1
#define PTHREAD_MUTEX_INITIALIZER 0
#define PTHREAD_COND_INITIALIZER 0

static inline int pthread_attr_init(pthread_attr_t *) { return 0; }
static inline int pthread_attr_destroy(pthread_attr_t *) { return 0; }
static inline int pthread_attr_setdetachstate(pthread_attr_t *, int) { return 0; }
static inline int pthread_create(pthread_t *, const pthread_attr_t *, void *(*)(void *), void *) { return -1; }

static inline int pthread_mutexattr_init(pthread_mutexattr_t *) { return 0; }
static inline int pthread_mutexattr_destroy(pthread_mutexattr_t *) { return 0; }
static inline int pthread_mutexattr_settype(pthread_mutexattr_t *, int) { return 0; }
static inline int pthread_mutex_init(pthread_mutex_t *, const pthread_mutexattr_t *) { return 0; }
static inline int pthread_mutex_destroy(pthread_mutex_t *) { return 0; }
static inline int pthread_mutex_lock(pthread_mutex_t *) { return 0; }
static inline int pthread_mutex_trylock(pthread_mutex_t *) { return 0; }
static inline int pthread_mutex_unlock(pthread_mutex_t *) { return 0; }

static inline int pthread_condattr_init(pthread_condattr_t *) { return 0; }
static inline int pthread_condattr_destroy(pthread_condattr_t *) { return 0; }
static inline int pthread_cond_init(pthread_cond_t *, const pthread_condattr_t *) { return 0; }
static inline int pthread_cond_destroy(pthread_cond_t *) { return 0; }
static inline int pthread_cond_signal(pthread_cond_t *) { return 0; }
static inline int pthread_cond_broadcast(pthread_cond_t *) { return 0; }
static inline int pthread_cond_wait(pthread_cond_t *, pthread_mutex_t *) { return 0; }
static inline int pthread_cond_timedwait(pthread_cond_t *, pthread_mutex_t *, const struct timespec *) { return 0; }

static inline int pthread_once(pthread_once_t *once, void (*routine)(void))
{
    if (!*once)
    {
        *once = 1;
        routine();
    }
    return 0;
}

// A key is the one slot every thread would have had its own copy of.
static inline int pthread_key_create(pthread_key_t *key, void (*)(void *))
{
    *key = (void **)calloc(1, sizeof(void *));
    return *key ? 0 : -1;
}

static inline void *pthread_getspecific(pthread_key_t key)
{
    return *key;
}

static inline int pthread_setspecific(pthread_key_t key, const void *value)
{
    *key = (void *)value;
    return 0;
}
