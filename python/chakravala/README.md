# chakravala
Solves Pell's equation $a^2 - Nb^2 = 1$ using the
[Chakravala method](https://en.wikipedia.org/wiki/Chakravala_method).

The method iteratively finds solutions to the more general equation
$a^2 - Nb^2 = k$ and stops when $k = 1$.

The script `chakravala.py` runs the method for every non-square $N$ below
10000. It prints each $N$ that needs more iterations than any smaller $N$,
together with the solution.
