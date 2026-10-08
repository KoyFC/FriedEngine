#pragma once

#include <sys/types.h>
#include <time.h>

struct timeval
{
    time_t tv_sec;
    long tv_usec;
};

#ifdef __cplusplus
extern "C" {
#endif

int gettimeofday(struct timeval *now, void *timezone);

#ifdef __cplusplus
}
#endif
