#! /usr/bin/env python3

def get_q(dividend, divisor):
    #print(f"dividend={dividend}, divisor={divisor}")
    assert abs(dividend/divisor) < 8/3
    assert abs(dividend) < 4
    if dividend > 0:
        return int(dividend/divisor + 0.5)
    else:
        return int(dividend/divisor - 0.5)

def srt(dividend, divisor):
    global max_dividend
    global max_quotient
    #print(f"dividend={dividend}, divisor={divisor}")
    if divisor < 0:
        dividend = -dividend
        divisor  = -divisor
    exp = 0
    while int(abs(dividend)) >= 2:
        dividend /= 2
        exp += 1
    while int(abs(divisor)) >= 2:
        divisor /= 2
        exp -= 1
    #print(f"=> exp={exp}")

    if abs(dividend) > max_dividend:
        max_dividend = abs(dividend)
    if abs(dividend/divisor) > max_quotient:
        max_quotient = abs(dividend/divisor)

    res = 0.0
    for i in range(28):
        q = get_q(dividend, divisor)
        #print(f"=> q={q}")
        assert abs(q) <= 2
        dividend -= q*divisor
        dividend *= 4
        res += q*(0.25**i)
        if abs(dividend) > max_dividend:
            max_dividend = abs(dividend)
        if abs(dividend/divisor) > max_quotient:
            max_quotient = abs(dividend/divisor)
    res *= 2.0**exp
    return res


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

