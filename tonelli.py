#! /usr/bin/env python

# This follows the algorithm outlined in https://en.wikipedia.org/wiki/Tonelli%E2%80%93Shanks_algorithm

import math

def is_prime(a):
    return all(a % i for i in range(2, math.isqrt(a)+1))

def find_z(p):
    assert is_prime(p)
    for z in range(2, p-1):
        if pow(z, (p-1)//2, p) == p-1:
            return z
    assert False

def find_pow(n, a):
    s = 0
    while (n % a) == 0:
        s += 1
        n //= a
    return (n,s)

def find_sqrt(n,p):
    assert is_prime(p)
    assert n < p
    assert pow(n, (p-1)//2, p) == 1

    # Step 1
    (q,s) = find_pow(p-1, 2)

    # Step 2
    z = find_z(p)

    # Step 3
    m = s
    c = pow(z, q, p)
    t = pow(n, q, p)
    r = pow(n, (q+1)//2, p)

    # Step 4
    while True:
        if t == 0:
            return 0
        if t == 1:
            assert pow(r, 2, p) == n
            return r
        tt = t
        for i in range(0, m):
            if tt == 1:
                break
            tt = tt*2 % p
        assert i < m
        b = c
        for j in range(0, m-i-1):
            b = b*c % p
        m = i
        c = b*b % p
        t = t*b*b % p
        r = r*b % p

def main():
    assert find_sqrt(5, 41) == 28    # Because 28^2 = 5 mod 41
    assert find_sqrt(13, 127) == 34  # Because 34^2 = 13 mod 127

    p = int(input("Input p:"))
    n = int(input("Input n:"))
    r = find_sqrt(n,p)
    assert pow(r, 2, p) == n
    print(r)

if __name__ == '__main__':
    main()

