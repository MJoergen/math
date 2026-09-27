#! /usr/bin/env python3

# Reference model of radix-4 SRT division, using floating point.
#
# Unlike the hardware, this model selects each quotient digit from the exact
# value of dividend/divisor, rather than from a table indexed by the top few
# bits. It is used to check the algorithm, and to find the largest partial
# remainder (max_dividend) and ratio (max_quotient) that occur. These bounds
# determine how many integer bits the hardware needs.
#
# See also srt.cpp, which does the same thing, but faster.

# Select the quotient digit q in {-2, -1, 0, 1, 2}, by rounding dividend/divisor
# to the nearest integer.
def get_q(dividend, divisor):
    # The algorithm only requires |dividend/divisor| < 8/3 (= 4 * 2/3). But
    # since this model rounds the exact ratio, |dividend - q*divisor| <=
    # divisor/2, so after multiplying by 4 the ratio is at most 2, and the
    # dividend stays below 4 (because divisor < 2).
    assert abs(dividend/divisor) < 8/3
    assert abs(dividend) < 4
    if dividend > 0:
        return int(dividend/divisor + 0.5)
    else:
        return int(dividend/divisor - 0.5)

# Calculate dividend/divisor using radix-4 SRT division.
def srt(dividend, divisor):
    global max_dividend
    global max_quotient
    if divisor < 0:
        dividend = -dividend
        divisor  = -divisor

    # Normalize both values to the range [1, 2), and remember the scaling
    exp = 0
    while int(abs(dividend)) >= 2:
        dividend /= 2
        exp += 1
    while int(abs(divisor)) >= 2:
        divisor /= 2
        exp -= 1

    if abs(dividend) > max_dividend:
        max_dividend = abs(dividend)
    if abs(dividend/divisor) > max_quotient:
        max_quotient = abs(dividend/divisor)

    # Each iteration produces one quotient digit (two bits) of the result
    res = 0.0
    for i in range(28):
        q = get_q(dividend, divisor)
        assert abs(q) <= 2
        dividend -= q*divisor
        dividend *= 4
        res += q*(0.25**i)
        if abs(dividend) > max_dividend:
            max_dividend = abs(dividend)
        if abs(dividend/divisor) > max_quotient:
            max_quotient = abs(dividend/divisor)

    # Undo the normalization
    res *= 2.0**exp
    return res


# Try many divisions and print each time a larger error is found.
def main():
    global max_dividend
    global max_quotient
    max_dividend = 0
    max_quotient = 0

    max_diff = 0
    for i in range(-1000, 1000):
        for j in range(1, 1000):
            res = srt(i, j)
            diff = abs(i/j - res)
            if diff > max_diff:
                max_diff = diff
                print(f"i={i}, j={j}, res={res}, diff={diff}")

    print(f"max_dividend={max_dividend}")
    print(f"max_quotient={max_quotient}")

main()
