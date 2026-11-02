#ifndef CSPEED_MATH_H
#define CSPEED_MATH_H

#include <stdint.h>

typedef struct {
    uint64_t received;
    uint64_t sent;
} CSpeedCounters;

typedef struct {
    double downloadBytesPerSecond;
    double uploadBytesPerSecond;
} CSpeedRates;

// Counter resets and invalid sample intervals produce zero rates.
CSpeedRates CSpeedCalculateRates(CSpeedCounters previous, CSpeedCounters current,
                                double elapsedSeconds);

#endif
