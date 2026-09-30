# Sine and cosine with CORDIC
This explains how [`c64_sincos.vhd`](c64_sincos.vhd) calculates the sine and
the cosine of a C64 floating point number with
[CORDIC](https://en.wikipedia.org/wiki/CORDIC): the range reduction, the
iterations, the reconstruction of the result from the octant, and what limits
the accuracy.

## Overview
The calculation has five steps, each with its own state:
1. `STAGE1_ST`: Reduce the angle modulo 2pi, as a fixed-point fraction of a
   full turn.
2. `STAGE2_ST`: Determine the octant, and reduce the angle to [0, pi/4].
3. `CALC_ST`: The 33 CORDIC iterations, one per clock cycle.
4. `SHIFT_ST`: Normalize x and y, i.e. find their exponents.
5. `NORMALIZE_ST`: Construct the sine and cosine from x, y, and the octant,
   and write them to the output register.

Together with the clock cycle where the input is accepted, this is a latency
of 37 clock cycles, i.e. 237 ns at 156 MHz.

The fixed-point numbers (`fraction_type` in
[`c64_sincos_pkg.vhd`](c64_sincos_pkg.vhd)) have 40 bits: one integer bit (or
sign bit), and 39 fractional bits, i.e. the 32 bits of the mantissa and 7
guard bits.

## Range reduction
The input is $x = m \cdot 2^{e-128}$ (see
[README.md](README.md#the-number-format)). The sine and cosine only depend on
the position of $x$ within a full turn, i.e. on the fractional part of
$\frac{x}{2\pi}$. This is calculated in two steps:
* The mantissa $m$ (with the leading one, and without the sign) is multiplied
  by the constant $\frac{2}{\pi}$ (40 bits). This is the only multiplication
  in the design, and uses 4 DSP blocks. The product $m \cdot \frac{2}{\pi}$
  is registered.
* The product is shifted by the exponent. With the scaling of the registers,
  shifting by $130 - e$ bits to the right (or to the left, if this is
  negative) gives $\frac{x}{2\pi}$, and the bits shifted out at the top are
  just the whole turns, which do not matter. So this is the reduction modulo
  $2\pi$.

The top three fractional bits of $\frac{x}{2\pi}$ are the octant (in units of
$\frac{\pi}{4}$), and the remaining bits are the position within the octant.
For an odd octant the position is mirrored (all bits are inverted), so the
angle given to CORDIC is always in $[0, \frac{\pi}{4}]$. It is then scaled so
that 1.0 means $\frac{\pi}{2}$, i.e. it is in $[0, 0.5]$.

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

The shifts by $i$ bits, where $i$ is the iteration count, are variable
shifters (barrel shifters), which are the largest part of the design.

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

The normalization is registered, so it is one clock cycle behind x and y.
This is why `SHIFT_ST` waits one clock cycle after the last iteration. (An
earlier version of the design did not, and so lost the last iteration.)

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
The design meets the 156 MHz constraint (6.4 ns) with a slack of 0.228 ns.
The worst path is the normalization of y: counting the leading zeros of the
40-bit y, and shifting it by that amount, with 7 logic levels.

It uses 1305 LUTs, 385 flip-flops, and 4 DSP blocks. A large part of the LUTs
are the five variable shifters of 40 bits: two in the CORDIC iteration, two in
the normalization, and one in the range reduction.

## Trade-offs
Each CORDIC iteration adds about one bit of accuracy, and 6.4 ns of latency.
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
* **Two bits per clock cycle:** Doing two iterations per clock cycle would
  halve the number of clock cycles, but put two variable shifts and additions
  in series, so the clock frequency would drop.
