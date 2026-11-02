#include "../CSpeedMath.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>

static void closeEnough(double actual, double expected)
{
    assert(fabs(actual - expected) < 0.0001);
}

int main(void)
{
    CSpeedCounters first = {1000, 500};
    CSpeedCounters second = {3000, 1500};
    CSpeedRates measured = CSpeedCalculateRates(first, second, 2.0);
    closeEnough(measured.downloadBytesPerSecond, 1000.0);
    closeEnough(measured.uploadBytesPerSecond, 500.0);

    measured = CSpeedCalculateRates(first, second, 0.0);
    closeEnough(measured.downloadBytesPerSecond, 0.0);
    closeEnough(measured.uploadBytesPerSecond, 0.0);

    measured = CSpeedCalculateRates(second, first, 1.0);
    closeEnough(measured.downloadBytesPerSecond, 0.0);
    closeEnough(measured.uploadBytesPerSecond, 0.0);

    measured = CSpeedCalculateRates((CSpeedCounters){500, 100},
                                    (CSpeedCounters){400, 300}, 0.5);
    closeEnough(measured.downloadBytesPerSecond, 0.0);
    closeEnough(measured.uploadBytesPerSecond, 400.0);

    puts("CSpeed rate calculation: all tests passed");
    return 0;
}
