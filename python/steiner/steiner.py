#!/usr/bin/env python3

# This tries to find Steiner Systems, see:
# https://en.wikipedia.org/wiki/Steiner_system
#
# A Steiner system S(t,k,n) is a collection of k-element subsets (blocks)
# of an n-element set, such that every t-element subset is contained in
# exactly one block.
#
# The search uses backtracking: In each step it finds the first t-subset that
# is not yet covered by any block, and then tries each block that contains
# this t-subset and is compatible with the blocks chosen so far.

from itertools import combinations
from typing import List
from typing import Iterator
from typing import Optional
from typing import Set
from typing import Tuple

def binom(n:int, k:int) -> int:
    r = 1
    for i in range(1,k+1):
        r*=n+1-i
        r//=i # This division will always be exact
    return r

# Number of blocks in the Steiner system S(t,k,n)
def calc_b(n:int, k:int, t:int) -> int:
    return binom(n,t) // binom(k,t)

# Number of blocks containing any given point
def calc_r(n:int, k:int, t:int) -> int:
    return binom(n-1,t-1) // binom(k-1,t-1)

# Convert a block to a list of n elements, each 0 or 1
def to_col(n:int, block:Tuple[int, ...]) -> List[int]:
    col = [0]*n
    for i in block:
        col[i] = 1
    return col

# n       : Total number of points
# k       : Number of points in each block
# t       : Every t-subset must be in exactly one block
# blocks  : The blocks chosen so far
# covered : The t-subsets contained in the blocks chosen so far
def steiner(n       : int,
            k       : int,
            t       : int,
            blocks  : Optional[List[Tuple[int, ...]]] = None,
            covered : Optional[Set[Tuple[int, ...]]]  = None) -> Iterator[List[List[int]]]:
    if blocks is None:
        print(f"n={n}, k={k}, t={t}, b={calc_b(n,k,t)}, r={calc_r(n,k,t)}")
        blocks = []
        covered = set()
    assert covered is not None

    # Find the first t-subset not yet covered
    first = next((s for s in combinations(range(n), t) if s not in covered), None)
    if first is None:
        # All t-subsets are covered, so we have a Steiner system
        assert len(blocks) == calc_b(n,k,t)
        yield [to_col(n, block) for block in blocks]
        return

    # Try each block containing this t-subset.
    # The block is the t-subset together with k-t of the remaining points.
    rest = [i for i in range(n) if i not in first]
    for extra in combinations(rest, k-t):
        block = tuple(sorted(first + extra))
        subsets = list(combinations(block, t))
        if any(s in covered for s in subsets):
            continue
        blocks.append(block)
        covered.update(subsets)
        yield from steiner(n, k, t, blocks, covered)
        covered.difference_update(subsets)
        blocks.pop()

def main() -> None:
    for (t,k,n) in [(2,3,7), (3,4,8), (3,4,10), (4,5,11), (5,6,12), (4,7,23), (5,8,24)]:
        for s in steiner(n,k,t):
            for col in s:
                print(''.join(str(i) for i in col))
            print()
            break

if __name__ == '__main__':
    main()
