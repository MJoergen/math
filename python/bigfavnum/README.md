# bigfavnum
Searches for integer solutions to the equation

$$\frac{x}{y+z} + \frac{y}{x+z} + \frac{z}{x+y} = 4$$

inspired by [this video](https://www.youtube.com/watch?v=Ct3lCfgJV_A).

Setting $z=1$ turns the equation into a cubic curve in $(x,y)$. Starting
from the known solution $(-11, -4, 1)$, the script `bigfavnum.py` tries four
different methods to find rational points on that curve:

* A: Repeatedly drawing tangents and secants through known points.
* B: Searching for rational $x$ for small rational $y$ (from a Farey sequence).
* C: Substituting $x=u+v$, $y=u-v$ and searching for values of $u$ that make
  $v^2$ a perfect square.
* D: Transforming to the elliptic curve $B^2 = A^3 + 109A^2 + 224A$ and
  searching it directly.

Requires [`gmpy2`](https://pypi.org/project/gmpy2/).
