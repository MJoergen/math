# limit
Estimates the limit of a sequence $a_n$ from a finite number of its terms,
using three consecutive terms at a time.

The script `limit.py` uses two estimators:

* Exponential: assumes $a_n = a + b c^n$ with $|c| < 1$, giving
  $a = \dfrac{a_{n+2} a_n - a_{n+1}^2}{a_{n+2} + a_n - 2a_{n+1}}$.
* Power: assumes $a_n = a + b/(n+c)$, giving
  $a = \dfrac{a_n(a_{n+2} - a_{n+1}) - a_{n+2}(a_{n+1} - a_n)}{a_{n+2} - 2a_{n+1} + a_n}$.

The script tests both estimators on sequences that follow these forms exactly
and on sequences that follow them only approximately.
