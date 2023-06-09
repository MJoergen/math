#!/usr/bin/env python3

# https://www.quora.com/How-do-you-prove-that-displaystyle-sum_-1-leq-m-2-n-2-leq-R-2-frac-1-m-2-n-2-2-pi-ln-R-O-1

import math
from typing import Iterator
from typing import Tuple
from typing import Dict
from typing import List

MAXR = 8000

# With MAXR = 4000 I get the following output (after approx 1 minutes):
# r= 2000, sum=50.342854, est=47.757879, diff=2.584975353
# r= 2200, sum=50.941689, est=48.356730, diff=2.584958732
# r= 2400, sum=51.488407, est=48.903439, diff=2.584967750
# r= 2600, sum=51.991312, est=49.406362, diff=2.584950199
# r= 2800, sum=52.456949, est=49.871996, diff=2.584953008
# r= 3000, sum=52.890458, est=50.305491, diff=2.584966550
# r= 3200, sum=53.295964, est=50.710999, diff=2.584964984
# r= 3400, sum=53.676887, est=51.091914, diff=2.584972583
# r= 3600, sum=54.036016, est=51.451051, diff=2.584964800
# r= 3800, sum=54.375733, est=51.790766, diff=2.584967845
# r= 4000, sum=54.698023, est=52.113051, diff=2.584972168

# With MAXR = 8000 I get the following output (after approx 4 minutes):
# r= 4000, sum=54.698023, est=52.113051, diff=2.584972168
# r= 4400, sum=55.296871, est=52.711902, diff=2.584969116
# r= 4800, sum=55.843585, est=53.258611, diff=2.584974218
# r= 5200, sum=56.346504, est=53.761534, diff=2.584969912
# r= 5600, sum=56.812142, est=54.227168, diff=2.584973704
# r= 6000, sum=57.245641, est=54.660663, diff=2.584977578
# r= 6400, sum=57.651142, est=55.066171, diff=2.584971650
# r= 6800, sum=58.032065, est=55.447086, diff=2.584978401
# r= 7200, sum=58.391200, est=55.806223, diff=2.584976857
# r= 7600, sum=58.730916, est=56.145938, diff=2.584978181
# r= 8000, sum=59.053201, est=56.468223, diff=2.584977872

# With MAXR = 16000 I get the following output (after approx 15 minutes):
# r= 8000, sum=59.053201, est=56.468223, diff=2.584977872
# r= 8800, sum=59.652052, est=57.067075, diff=2.584977858
# r= 9600, sum=60.198763, est=57.613783, diff=2.584980263
# r=10400, sum=60.701686, est=58.116706, diff=2.584979611
# r=11200, sum=61.167319, est=58.582340, diff=2.584978240
# r=12000, sum=61.600815, est=59.015835, diff=2.584979530
# r=12800, sum=62.006322, est=59.421343, diff=2.584978858
# r=13600, sum=62.387239, est=59.802259, diff=2.584980418
# r=14400, sum=62.746375, est=60.161396, diff=2.584979929
# r=15200, sum=63.086091, est=60.501110, diff=2.584980800
# r=16000, sum=63.408376, est=60.823395, diff=2.584980344


# This is an extended Sieve of Erastosthenes, where it generates a complete prime
# factorization of all integers up to some given maximum.

def primefaclist(n:int) -> List[Dict[int,int]]:
    a = [dict() for i in range(n)]
    old_percent = -1
    for p in range(2, len(a)):
        if len(a[p]) > 0:
            continue
        f = p
        while f < len(a):
            for i in range(f, len(a), f):
                if p in a[i]:
                    a[i][p] += 1
                else:
                    a[i][p] = 1
            f *= p
        percent = ((1000*p)//len(a))/10
        if percent != old_percent:
            if percent <= 10 or (int(10*percent) % 100) == 0:
                print(f"p={p:9d} : {percent}%    \r", flush=True)
            if percent > 0:
                old_percent = percent
    return a

print(f"Generating prime factorizations using Sieve of Erasthostenes up to {MAXR*MAXR}:")
primefac=primefaclist(MAXR*MAXR+1)

# This calculates the function H(k), which is the number of
# solutions to x^2+y^2 = k, where (x,y) in Z^2.
# This is actually just the "Sum of two squares function"
# i.e. the number of ways to write an integer n as
# the sum of two squares.
# https://en.wikipedia.org/wiki/Sum_of_squares_function
# The implementation here uses the primefactorization to
# quickly evaluate the result.
def r2(n):
    #ml = list(primefac.primefac(n))
    #md = {i:ml.count(i) for i in ml}
    md = primefac[n]
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
def calc_all_sums(maxr) -> Iterator[Tuple[int, float]]:
    sum = 0.0
    for k in range(1, maxr*maxr+1):
        sum += r2(k) / k
        yield(k, sum)

def main():
    pi = 4.0*math.atan(1.0)
    r = MAXR//2
    for i,sum in calc_all_sums(MAXR):
        if i==r*r:
            est = 2.0*pi*math.log(r)
            diff = sum - est
            print(f"r={r}, sum={sum:9f}, est={est:9f}, diff={diff:11.9f}")
            r += MAXR//20

if __name__ == '__main__':
    main()

