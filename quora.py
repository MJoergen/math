#!/usr/bin/env python3

import math
import primefac # type: ignore

# https://www.quora.com/How-do-you-prove-that-displaystyle-sum_-1-leq-m-2-n-2-leq-R-2-frac-1-m-2-n-2-2-pi-ln-R-O-1

# This calculates the function H(k), which is the number of
# solutions to x^2+y^2 = k, where (x,y) in Z^2.
# This is actually just the "Sum of two squares function"
# i.e. the number of ways to write an integer n as
# the sum of two squares.
# https://en.wikipedia.org/wiki/Sum_of_squares_function
# The implementation here uses the primefactorization to
# quickly evaluate the result.
def r2(n):
    ml = list(primefac.primefac(n))
    md = {i:ml.count(i) for i in ml}
    res = 4
    for prime,exp in md.items():
        if prime == 2:
            continue
        if prime%4 == 1:
            res *= exp+1
        if prime%4 == 3:
            if exp%2 == 1:
                return 0
    return res

# This calculates the sum from 1 to R^2 of H(k)/k.
def calc_sum(r):
    sum = 0.0
    for k in range(1, r*r+1):
        sum += r2(k) / k
    return sum

if __name__ == '__main__':
    pi = 4.0*math.atan(1.0)
    for r in range(100, 1001, 100):
        sum = calc_sum(r)
        est = 2.0*pi*math.log(r)
        diff = sum - est
        print(f"r={r}, sum={sum}, est={est}, diff={diff}")

