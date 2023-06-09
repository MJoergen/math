#!/usr/bin/env python3

# This tries to find Steiner Systems, see:
# https://en.wikipedia.org/wiki/Steiner_system

from typing import List
from typing import Iterator

# n      : Total number of positions available
# k      : Total number of filled positions wanted
# a_temp : Current, half-filled, array
# k_temp : Number of currently filled positions
# pos    : Position after last filled position
def place(n:int, k:int, a_temp:List[int] = None, k_temp:int = None, pos:int = None) -> Iterator[List[int]]:
    if a_temp == None:
        a_temp = [0]*n
    if k_temp == None:
        k_temp = sum(a_temp)
    if pos == None:
        pos = 0
    if k_temp == k:
        yield a_temp
    for i in range(pos,n):
        a_temp[i] = 1
        yield from place(n, k, a_temp, k_temp+1, i+1)
        a_temp[i] = 0

def binom(n:int, k:int) -> int:
    r = 1
    for i in range(1,k+1):
        r*=n+1-i
        r//=i # This division will always be exact
    return r

def count(a:List[int]) -> int:
    s = 0
    for i in a:
        if i != 0:
            s += 1
    return s

def valid(cols:List[List[int]], c:List[int], t:int) -> bool:
    for pc in cols:
        if sum([a*b for a,b in zip(pc,c)]) >= t:
            return False
    return True

def steiner(n         : int,
            k         : int,
            t         : int,
            b         : int             = None,
            r         : int             = None,
            cols      : List[List[int]] = None,
            col_index : int             = 0,
            all_cols  : List[List[int]] = None) -> Iterator[List[List[int]]]:
    if b == None:
        b = calc_b(n,k,t)
    assert b is not None
    if r == None:
        r = calc_r(n,k,t)
    assert r is not None
    if all_cols == None:
        print(f"n={n}, k={k}, t={t}, b={b}, r={r}")
        all_cols = []
        for c in place(n, k):
            all_cols.append(list(c))
    assert all_cols is not None

    if cols == None:
        cols=[]
    else:
        assert cols is not None
        res = [sum(i) for i in zip(*cols)]
        if max(res) > r:
            print("Illegal")
            return

    if len(cols) >= binom(n,t) // binom(k,t):
        yield cols

    for i in range(col_index, len(all_cols)):
        c = all_cols[i]
        if valid(cols,c,t):
            cols.append(c)
            yield from steiner(n, k, t, b, r, list(cols), i, all_cols)
            cols.pop()

for s in steiner(7,3,2):
    print(s)
    break

for s in steiner(9,3,2):
    print(s)
    break

for s in steiner(15,3,2):
    print(s)
    break

for s in steiner(8,4,3):
    print(s)
    break

# The rest fail for some reason
for s in steiner(10,4,3):
    print(s)
    break

for s in steiner(11,5,4):
    print(s)
    break

for s in steiner(23,7,4):
    print(s)
    break

for s in steiner(12,6,5):
    print(s)
    break

for s in steiner(24,8,5):
    print(s)
    break

