#include "CSpeedMath.h"

#include <math.h>

CSpeedRates CSpeedCalculateRates(CSpeedCounters previous, CSpeedCounters current,
                                double elapsedSeconds)
{
    CSpeedRates rates = {0.0, 0.0};
    if (!isfinite(elapsedSeconds) || elapsedSeconds <= 0.0) {
        return rates;
    }

    if (current.received >= previous.received) {
        rates.downloadBytesPerSecond =
            (double)(current.received - previous.received) / elapsedSeconds;
    }
    if (current.sent >= previous.sent) {
        rates.uploadBytesPerSecond =
            (double)(current.sent - previous.sent) / elapsedSeconds;
    }
    return rates;
}
