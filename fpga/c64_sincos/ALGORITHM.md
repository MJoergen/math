# Sine and cosine with CORDIC
This explains how [`c64_sincos.vhd`](c64_sincos.vhd) calculates the sine and
the cosine of a C64 floating point number with
[CORDIC](https://en.wikipedia.org/wiki/CORDIC): the range reduction, the
iterations, the reconstruction of the result from the octant, and what limits
the accuracy.

## Overview
The calculation has five steps, in three states:
1. `REDUCE_ST`: Reduce the angle modulo 2pi, as a fixed-point fraction of a
   full turn.
2. `REDUCE_ST`: Determine the octant, and reduce the angle to [0, pi/4]. The
   first CORDIC iteration is done here too.
3. `CALC_ST`: The other 32 CORDIC iterations, `G_STEPS` in each clock cycle.
4. `NORMALIZE_ST`: Normalize x and y, i.e. find their exponents.
5. `NORMALIZE_ST`: Construct the sine and cosine from x, y, and the octant,
   and write them to the output register.

Together with the clock cycle where the input is accepted, this is a latency
of 32/`G_STEPS` + 2 clock cycles, i.e. 10 clock cycles (133 ns at 75.5 MHz)
for the default `G_STEPS=4`.

The fixed-point numbers (`fraction_type` in
[`c64_sincos_pkg.vhd`](c64_sincos_pkg.vhd)) have 40 bits: one integer bit (or
sign bit), and 39 fractional bits, i.e. the 32 bits of the mantissa and 7
guard bits.

## Range reduction
The input is $x = m \cdot 2^{e-128}$ (see
[README.md](../README.md#c64-floating-point-format)). The sine and cosine only depend on
the position of $x$ within a full turn, i.e. on the fractional part of
$\frac{x}{2\pi}$. This is calculated in two steps:
* The mantissa $m$ (with the leading one, and without the sign) is multiplied
  by the constant $\frac{2}{\pi}$ (40 bits). This is the only multiplication
  in the design, and uses 4 DSP blocks.
* The product is shifted by the exponent. With the scaling of the registers,
  shifting by $130 - e$ bits to the right (or to the left, if this is
  negative) gives $\frac{x}{2\pi}$, and the bits shifted out at the top are
  just the whole turns, which do not matter. So this is the reduction modulo
  $2\pi$.

The top three fractional bits of $\frac{x}{2\pi}$ are the octant (in units of
$\frac{\pi}{4}$), and the remaining bits are the position within the octant.
For an odd octant the position is mirrored (all bits are inverted), so the
angle given to CORDIC is always in $[0, \frac{\pi}{4}]$. It is then scaled so
that 1.0 means $\frac{\pi}{2}$, i.e. it is in $[0, 0.5]$. The
multiplication, the shift, and the mirroring are all done in the same clock
cycle (`REDUCE_ST`), and the octant is stored for the reconstruction of the
result.

The shift only covers exponents from `0x63` to `0xA3`, i.e.
$2^{-30} \le |x| < 2^{35}$. Smaller angles are treated as zero, which gives
$\sin x = 0$ (an absolute error below $2^{-30}$) and $\cos x = 1$. Larger
angles are treated as zero as well, but at $|x| \ge 2^{35}$ the C64 number
cannot even represent the angle to within a full turn, so no result would be
meaningful.

## CORDIC
CORDIC calculates $\cos\theta$ and $\sin\theta$ by rotating the vector
$(x, y) = (K, 0)$ by the angles $\pm\arctan(2^{-i})$, for $i = 0, 1, \ldots, 32$.
A rotation by $\pm\arctan(2^{-i})$ is
```math
x' = x \mp 2^{-i} y, \qquad y' = y \pm 2^{-i} x ,
```
times the factor $\sqrt{1 + 4^{-i}}$. So each rotation only needs two shifts
and two additions. The direction of each rotation is chosen so that the
remaining angle (the register `angle`) approaches zero: if it is positive, the
vector is rotated forwards, and $\arctan(2^{-i})$ is subtracted from the
remaining angle, and otherwise backwards. The angles $\arctan(2^{-i})$ are
constants in a small table (`C_ANGLES`), in units of $\frac{\pi}{2}$.

The rotations lengthen the vector by the factor $\prod_i \sqrt{1 + 4^{-i}}$,
so the vector starts with the length $K = \prod_i (1 + 4^{-i})^{-1/2} \approx 0.6073$
(`C_SCALE`). After the last rotation, $(x, y)$ is $(\cos\theta, \sin\theta)$,
up to the remaining angle, which is at most the angle of the last rotation,
$\arctan(2^{-32}) \approx 2^{-32}$. So each iteration adds about one bit of
accuracy, see [Trade-offs](#trade-offs).

The first iteration ($i = 0$) always rotates forwards, since the angle is
in $[0, \frac{\pi}{4}]$, i.e. not negative. It gives $(x, y) = (K, K)$, and
subtracts $\arctan(1) = \frac{\pi}{4}$, i.e. 0.5 in units of
$\frac{\pi}{2}$, from the angle. Since 0.5 is a single bit, this only
changes the top two bits of the angle, so it is done in `REDUCE_ST`, together
with the range reduction.

The other 32 iterations are done `G_STEPS` at a time, in 32/`G_STEPS` clock
cycles of `CALC_ST`, so 32 must be divisible by `G_STEPS`. Iteration $j$ in
the clock cycle `count` is iteration $i = 1 + \mathtt{count} \cdot
\mathtt{G\_STEPS} + j$. The shifts by $i$ bits are variable shifters
(barrel shifters), which are the largest part of the design. But since
`count` only takes 32/`G_STEPS` values, each shifter only selects between
32/`G_STEPS` shift amounts, e.g. 8 for `G_STEPS=4`. (An earlier version
shifted by `count + j`, where `count` stepped by `G_STEPS`, and Vivado then
built full 40-bit barrel shifters, which made each iteration about 1 ns
slower.) The iterations are the same as with one iteration in each clock
cycle, so the result is bit-identical for all values of `G_STEPS`.

## Reconstructing the result
Let $u$ be the position within the octant, so that the angle is
$\frac{\pi}{4} \cdot \mathit{octant} + u$. CORDIC gives
$(x, y) = (\cos\varphi, \sin\varphi)$, where $\varphi = u$ for an even octant,
and $\varphi = \frac{\pi}{4} - u$ for an odd octant. The sine and cosine then
follow from the symmetries of the unit circle:

| Octant | Angle                       | cos     | sin     |
| ------ | --------------------------- | ------- | ------- |
| 0      | $\varphi$                   | $x$     | $y$     |
| 1      | $\frac{\pi}{2} - \varphi$   | $y$     | $x$     |
| 2      | $\frac{\pi}{2} + \varphi$   | $-y$    | $x$     |
| 3      | $\pi - \varphi$             | $-x$    | $y$     |
| 4      | $\pi + \varphi$             | $-x$    | $-y$    |
| 5      | $\frac{3\pi}{2} - \varphi$  | $-y$    | $-x$    |
| 6      | $\frac{3\pi}{2} + \varphi$  | $y$     | $-x$    |
| 7      | $2\pi - \varphi$            | $x$     | $-y$    |

For a negative input, the sign of the sine is inverted, since
$\sin(-x) = -\sin x$ and $\cos(-x) = \cos x$. Since both x and y are
non-negative, the C64 results are just x and y, normalized, with the sign bit
from this table.

The normalization counts the leading zeros of x and y, which gives the
exponent, and shifts them to the left. The top 32 bits are the mantissa, so
the result is truncated, not rounded. Two corner cases are clamped: x is at
most 1.0, and a slightly negative y (from the remaining angle, when the angle
is close to zero) becomes zero.

The normalization is combinational, and is done in `NORMALIZE_ST`, in the
same clock cycle where the result is written to the output register. (In an
earlier version, the normalization was registered, and so one clock cycle
behind x and y, and an extra state waited for it.)

## Accuracy
The largest absolute error over 121 angles in $[0, \frac{\pi}{4}]$ is
$2^{-31.4}$, and $2^{-31.2}$ over $[-2\pi, 2\pi]$. It has three parts, which
are of similar size:
* The remaining angle after 33 iterations, at most about $2^{-32}$.
* The rounding errors in the 33 iterations, which the 7 guard bits keep
  small.
* The truncation of the result to 32 bits, up to $2^{-32}$ for results in
  $[0.5, 1)$.

The error is absolute, not relative, since the CORDIC iterations use fixed
point. So for small results the relative error is large. E.g.
$\sin(10^{-9})$ is calculated as $8.3 \cdot 10^{-10}$, which is within
$2^{-32}$ of the correct value, but only has about 3 correct digits.

For large angles, the precision of the range reduction limits the accuracy:
the constant $\frac{2}{\pi}$ has 40 bits, and the product with the mantissa is
shifted to the left by up to 33 bits, so the lower bits of $\frac{x}{2\pi}$
are missing. Compared with the sine and cosine of the C library:

| $x$                          | 10         | 100        | 1000       | $10^4$     | $10^5$     | $10^6$     |
| ---------------------------- | ---------- | ---------- | ---------- | ---------- | ---------- | ---------- |
| Largest error of sin and cos | $2^{-32.7}$ | $2^{-31.7}$ | $2^{-31.5}$ | $2^{-25.1}$ | $2^{-21.3}$ | $2^{-18.4}$ |

So above about $|x| = 1000$ the error grows roughly like $|x| \cdot 2^{-38}$.
A more precise reduction for large angles would need more bits of
$\frac{2}{\pi}$, as in the Payne-Hanek reduction (M. Payne and R. Hanek,
"Radian reduction for trigonometric functions", ACM SIGNUM Newsletter, 1983).

The testbench compares with the Taylor series, since the `sin` and `cos` of
`ieee.math_real` in GHDL are calculated with CORDIC too, and are only accurate
to about $2^{-28}$.

## Timing and resources
Each CORDIC iteration is a variable shift and an addition or subtraction of
40 bits, for each of x and y, and the direction depends on the sign of the
remaining angle after the previous iteration. So the `G_STEPS` iterations in
a clock cycle are in series, and each takes about 3 ns. The range reduction
(the multiplication, the shift by the exponent, and the mirroring) takes
about 10.5 ns, and the normalization about 7 ns, which limits the clock period
for small `G_STEPS`.

The latency for each value of `G_STEPS`, from `make vivado VIVADO_STEPS=n`
with the clock period in `c64_sincos.xdc` reduced until the timing was no
longer met. The clock period is the shortest one where the timing is met, and
the next shorter one that was tried (in parentheses) does not meet the timing.
The LUTs and flip-flops are the numbers that `make vivado` prints:

| `G_STEPS` | Clock cycles | Clock period        | Latency | LUT  | FF  |
| --------- | ------------ | ------------------- | ------- | ---- | --- |
| 1         | 34           | 10.5 ns (10.25 ns)  | 357 ns  | 1252 | 236 |
| 2         | 18           | 10.7 ns (10.4 ns)   | 193 ns  | 1479 | 238 |
| 4         | 10           | 12.9 ns (12.6 ns)   | 129 ns  | 1741 | 246 |
| 8         | 6            | 24.5 ns (24.0 ns)   | 147 ns  | 2268 | 237 |
| 16        | 4            | 46 ns (44 ns)       | 184 ns  | 3175 | 244 |

So the latency is lowest for `G_STEPS=4`, which is the default. With
`G_STEPS=1`, it uses 2 Block RAMs for the table of the angles. The timing is
sensitive to placement: For `G_STEPS=4`, a clock period of 12.9 ns is met,
but 13.0 ns is not, and for `G_STEPS=16`, 46 ns is met, but 48 ns is not. So
the constraint in `c64_sincos.xdc` is 13.25 ns (75.5 MHz), which is met with
a slack of 0.456 ns, for a latency of 133 ns. The critical path then is the
four iterations of y, with 39 logic levels.

The earlier version, with one iteration in each clock cycle, and separate
clock cycles for the multiplication, the first iteration, and the
normalization, needed 37 clock cycles. It met a clock period of 6.1 ns, i.e. a
latency of 226 ns, with 1305 LUTs and 385 flip-flops. Its critical path was
the normalization. For `G_STEPS` of 1 or 2, such separate clock cycles would
give a lower latency than in the table above.

With `G_STEPS=4`, the design uses 1741 LUTs, 246 flip-flops (451 slices), and
4 DSP blocks. A large part of the LUTs are the variable shifters of 40 bits:
two in each CORDIC iteration, two in the normalization, and one in the range
reduction.

## Trade-offs
Each CORDIC iteration adds about one bit of accuracy, and about 3 ns of
latency.
Measured with the testbench (the largest error over the 121 angles in
$[0, \frac{\pi}{4}]$):

| Iterations | 28          | 29          | 30          | 31          | 32          | 33          | 34          |
| ---------- | ----------- | ----------- | ----------- | ----------- | ----------- | ----------- | ----------- |
| Error      | $2^{-27.0}$ | $2^{-28.0}$ | $2^{-29.0}$ | $2^{-30.0}$ | $2^{-30.8}$ | $2^{-31.4}$ | $2^{-31.7}$ |

Beyond 33 iterations the truncation of the result to 32 bits dominates, so
more iterations hardly help.

Some alternatives, which are not implemented:
* **Unrolled CORDIC:** With one hardware stage per iteration, each stage
  shifts by a constant, so there are no barrel shifters in the iterations, and
  with pipeline registers the design could accept a new angle in every clock
  cycle. But it would need 33 adders for each of x, y, and the angle.
* **Rounding:** Rounding the result instead of truncating it would reduce the
  largest error, at the cost of an adder in the normalization, which is
  already the critical path.
* **Fewer iterations with a multiplication:** After 20 iterations, the
  remaining angle $z$ is below $2^{-19}$, so $1 - \cos z < 2^{-39}$, and the
  remaining rotations are, to the precision of the calculation, a single
  rotation by $z$, i.e. $x' = x - z y$ and $y' = y + z x$ (with $K$ for the
  first 20 iterations only). Two multiplications could then replace the last
  13 iterations.
