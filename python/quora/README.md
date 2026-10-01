# quora
Numerically checks [this Quora question](https://www.quora.com/How-do-you-prove-that-displaystyle-sum_-1-leq-m-2-n-2-leq-R-2-frac-1-m-2-n-2-2-pi-ln-R-O-1),
which asks to prove that

$$\sum_{1 \le m^2+n^2 \le R^2} \frac{1}{m^2+n^2} = 2\pi \ln R + O(1).$$

The script `quora.py` groups the terms by $k = m^2+n^2$, so the sum becomes
$\sum_k r_2(k)/k$. Here $r_2(k)$ is the
[sum of squares function](https://en.wikipedia.org/wiki/Sum_of_squares_function),
which is computed quickly from prime factorizations made with a sieve.

The difference between the sum and $2\pi \ln R$ settles at about 2.58498.
The comments in the script contain sample output for $R$ up to 16000.
