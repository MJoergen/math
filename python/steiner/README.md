# steiner
Searches for [Steiner systems](https://en.wikipedia.org/wiki/Steiner_system)
$S(t, k, n)$: collections of $k$-element blocks from an $n$-element set such
that every $t$-element subset is contained in exactly one block.

The script `steiner.py` uses a backtracking search. It attempts $S(2,3,7)$ (the
Fano plane), $S(3,4,8)$, $S(3,4,10)$, $S(4,5,11)$, $S(4,7,23)$, $S(5,6,12)$
and $S(5,8,24)$.

Note: the script does not currently run, because the helper functions
`calc_b` and `calc_r` are not defined.
