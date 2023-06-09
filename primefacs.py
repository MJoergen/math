#!/usr/bin/env python3

# This is an extended Sieve of Erastosthenes, where it generates a complete prime
# factorization of all integers up to some given maximum.

from typing import List
from typing import Dict

def primefaclist(n:int) -> List[Dict[int,int]]:
    a = [dict() for i in range(n)]
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
    return a

def main():
    a = primefaclist(10000)
    for i,d in enumerate(a):
        print(f"i={i}: ",end='')
        for p,e in d.items():
            print(f"(p,e)=({p},{e}) ",end='')
        print()

if __name__ == '__main__':
    main()

