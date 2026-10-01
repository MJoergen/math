# bigfavnum_n
A generalization of [`bigfavnum`](../bigfavnum) that searches for positive
integer solutions to

$$\frac{x}{y+z} + \frac{y}{x+z} + \frac{z}{x+y} = n$$

for all even $n$ from 4 up to 200.

For each $n$, the script `bigfavnum_n.py` transforms the equation into an
elliptic curve. It then looks for a small non-torsion rational point and adds
points with the chord-and-tangent rule until it reaches a positive solution.
The values of $n$ are processed in parallel.

The output of a full run (about 20 hours) is in the comment at the top of the
script. It finds positive solutions for 22 values of $n$, including $n=34$,
$n=94$ and $n=114$, which are not listed in the paper by
[Bremner and Macleod](https://ami.uni-eszterhazy.hu/uploads/papers/finalpdf/AMI_43_from29to41.pdf).

Requires [`gmpy2`](https://pypi.org/project/gmpy2/) and
[`ray`](https://pypi.org/project/ray/).
