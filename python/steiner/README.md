# steiner
Searches for [Steiner systems](https://en.wikipedia.org/wiki/Steiner_system)
$S(t, k, n)$: collections of $k$-element blocks from an $n$-element set such
that every $t$-element subset is contained in exactly one block.

The script `steiner.py` uses a backtracking search. In each step it picks the
first $t$-subset that is not yet covered and tries each compatible block
containing it. It finds $S(2,3,7)$ (the Fano plane), $S(3,4,8)$, $S(3,4,10)$,
$S(4,5,11)$, $S(5,6,12)$, $S(4,7,23)$ and $S(5,8,24)$ in a few seconds.

Each system is printed with one block per line, as a string of 0s and 1s
marking which of the $n$ points are in the block.
