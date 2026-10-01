# python
Various Python scripts for exploring mathematical problems.

* [`bigfavnum.py`](bigfavnum.py): Searches for positive integer solutions to
  the equation $x/(y+z) + y/(x+z) + z/(x+y) = 4$.
* [`bigfavnum_n.py`](bigfavnum_n.py): The same as `bigfavnum.py`, but with
  other integers $n$ on the right-hand side instead of 4.
* [`card_distrib`](card_distrib): Counts the possible distributions of the four
  suits in a bridge hand, both by brute force and by using partition numbers.
* [`chakravala.py`](chakravala.py): Solves Pell's equation $a^2 - Nb^2 = 1$
  using the Chakravala method.
* [`circle`](circle): Generates a circle using only addition and subtraction,
  and analyses how integer rounding changes the period.
* [`limit.py`](limit.py): Estimates the limit of a sequence from a finite
  number of its terms.
* [`primefacs.py`](primefacs.py): An extended Sieve of Eratosthenes that finds
  the prime factorization of all integers up to a given maximum.
* [`quora.py`](quora.py): Numerically checks that the sum of
  $1/(m^2+n^2)$ over all $1 \le m^2+n^2 \le R^2$ is $2\pi \ln R + O(1)$.
* [`steiner.py`](steiner.py): Searches for Steiner systems.
* [`tonelli.py`](tonelli.py): Computes square roots modulo a prime using the
  Tonelli-Shanks algorithm.
