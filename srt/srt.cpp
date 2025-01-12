#include <stdio.h>
#include <assert.h>
#include <math.h>

static double get_q(double dividend, double divisor)
{
    assert(dividend/divisor < 8.0/3.0);
    assert(dividend < 4.0);

    if (dividend > 0.0)
    {
        return floor(dividend/divisor + 0.5);
    }
    else
    {
        return -floor(-dividend/divisor + 0.5);
    }
} // static double get_q(double dividend, double divisor)

static double max_dividend = 0.0;
static double max_quotient = 0.0;

static double srt(double dividend, double divisor)
{
//    printf("dividend=%f, divisor=%f\n", dividend, divisor);
    if (divisor < 0.0)
    {
        dividend = -dividend;
        divisor = -divisor;
    }

    double norm = 1.0;
    while (abs(dividend) >= 2.0)
    {
        dividend *= 0.5;
        norm *= 2.0;
    }
    while (abs(divisor) >= 2.0)
    {
        divisor *= 0.5;
        norm *= 0.5;
    }


    if (abs(dividend) > max_dividend)
        max_dividend = abs(dividend);
    if (abs(dividend/divisor) > max_quotient)
        max_quotient = abs(dividend/divisor);

    double res = 0.0;
    double factor = 1.0;
    for (int i=0; i<28; ++i)
    {
        double q = get_q(dividend, divisor);
        res += q*factor;
 //       printf(":: dividend=%f, divisor=%f, q=%f, res=%f\n", dividend, divisor, q, res);
        assert(abs(q) <= 2.0);
        factor *= 0.25;
        dividend -= q*divisor;
        dividend *= 4;
        if (abs(dividend) > max_dividend)
            max_dividend = abs(dividend);
        if (abs(dividend/divisor) > max_quotient)
            max_quotient = abs(dividend/divisor);
    }
    res *= norm;
//    printf(">> dividend=%f, divisor=%f, res=%f\n", dividend, divisor, res);
    return res;
}

static double max_diff = 0.0;

const double limit = 10000.0;

int main()
{
    for (double n=-limit; n<limit; n += 1.0)
    {
        for (double d=1.0; d<limit; d += 1.0)
        {
            double res = srt(n, d);
            double diff = abs(n/d - res);
            if (diff > max_diff)
            {
                max_diff = diff;
                printf("n={%lf}, d={%lf}, res={%lf}, diff={%lf}\n", n, d, res, diff);
            }
        }
    }

    srt(1.0, 3.0);

    printf("max_dividend={%f}\n", max_dividend);
    printf("max_quotient={%f}\n", max_quotient);
}

