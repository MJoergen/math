// Reference model of radix-4 SRT division, using floating point.
//
// Unlike the hardware, this model selects each quotient digit from the exact
// value of dividend/divisor, rather than from a table indexed by the top few
// bits. It is used to check the algorithm, and to find the largest partial
// remainder (max_dividend) and ratio (max_quotient) that occur. These bounds
// determine how many integer bits the hardware needs.
//
// This is a faster version of srt.py.

#include <stdio.h>
#include <assert.h>
#include <math.h>

// Select the quotient digit q in {-2, -1, 0, 1, 2}, by rounding
// dividend/divisor to the nearest integer.
static double get_q(double dividend, double divisor)
{
    // The algorithm only requires |dividend/divisor| < 8/3 (= 4 * 2/3). But
    // since this model rounds the exact ratio, |dividend - q*divisor| <=
    // divisor/2, so after multiplying by 4 the ratio is at most 2, and the
    // dividend stays below 4 (because divisor < 2).
    assert(fabs(dividend/divisor) < 8.0/3.0);
    assert(fabs(dividend) < 4.0);

    if (dividend > 0.0)
    {
        return floor(dividend/divisor + 0.5);
    }
    else
    {
        return -floor(-dividend/divisor + 0.5);
    }
} // static double get_q(double dividend, double divisor)

// The largest values seen during all divisions
static double max_dividend = 0.0;
static double max_quotient = 0.0;

// Calculate dividend/divisor using radix-4 SRT division.
static double srt(double dividend, double divisor)
{
    if (divisor < 0.0)
    {
        dividend = -dividend;
        divisor = -divisor;
    }

    // Normalize both values to the range [1, 2), and remember the scaling
    double norm = 1.0;
    while (fabs(dividend) >= 2.0)
    {
        dividend *= 0.5;
        norm *= 2.0;
    }
    while (fabs(divisor) >= 2.0)
    {
        divisor *= 0.5;
        norm *= 0.5;
    }

    if (fabs(dividend) > max_dividend)
        max_dividend = fabs(dividend);
    if (fabs(dividend/divisor) > max_quotient)
        max_quotient = fabs(dividend/divisor);

    // Each iteration produces one quotient digit (two bits) of the result
    double res = 0.0;
    double factor = 1.0;
    for (int i=0; i<28; ++i)
    {
        double q = get_q(dividend, divisor);
        res += q*factor;
        assert(fabs(q) <= 2.0);
        factor *= 0.25;
        dividend -= q*divisor;
        dividend *= 4;
        if (fabs(dividend) > max_dividend)
            max_dividend = fabs(dividend);
        if (fabs(dividend/divisor) > max_quotient)
            max_quotient = fabs(dividend/divisor);
    }

    // Undo the normalization
    res *= norm;
    return res;
}

static double max_diff = 0.0;

const double limit = 10000.0;

// Try many divisions and print each time a larger error is found.
int main()
{
    for (double n=-limit; n<limit; n += 1.0)
    {
        for (double d=1.0; d<limit; d += 1.0)
        {
            double res = srt(n, d);
            double diff = fabs(n/d - res);
            if (diff > max_diff)
            {
                max_diff = diff;
                printf("n=%f, d=%f, res=%f, diff=%g\n", n, d, res, diff);
            }
        }
    }

    printf("max_dividend=%f\n", max_dividend);
    printf("max_quotient=%f\n", max_quotient);
}
