# Tangent CORDIC of the 8087
This explains how [`tan_cordic.vhd`](tan_cordic.vhd) calculates `tan(angle)`,
with the variant of [CORDIC](https://en.wikipedia.org/wiki/CORDIC) used by
the Intel 8087, as described in
[this article](https://www.righto.com/2026/09/8087-tangent-cordic.html): why
each phase works, how many iterations are needed, and the timing.

## Overview
The classical CORDIC algorithm calculates `sin` and `cos` by rotating the vector
`(1, 0)` by the target angle, one step at a time, using only additions, subtractions,
and shifts. Each step either adds or subtracts a special angle `arctan(2**-i)`, chosen
so that the correction shrinks the remaining angle at every step, regardless of its
sign. Because tangent is just `sin/cos = y/x`, and this ratio does not depend on the
length of the vector, the usual CORDIC scale-factor correction can be skipped
entirely when only the tangent is wanted.

Doing this angle-by-angle correction for a full 64-bit result would need 64
iterations. To get a fast result with only `G_ITERATIONS` (6 by default) iterations, this
module (like the 8087) instead splits the calculation into three phases, followed by
a division:

1. **Pseudo-division:** Write the angle $\theta$ as a sum of special angles
   $\arctan(2^{-i})$, plus a tiny residual angle $z$.
2. **Padé approximation:** Approximate $\tan z$ by a fraction $y_0/x_0$.
3. **Pseudo-multiplication:** Rotate the vector $(x_0, y_0)$ by the special
   angles from phase 1. Then $y/x = \tan\theta$.
4. **Division:** Calculate $y/x$.

## Phase 1: Pseudo-division
The input angle is repeatedly compared against a table of decreasing special angles
`arctan(2**-i)`, for `i = 0 .. G_ITERATIONS-1`. Whenever the current special angle
fits inside the remaining angle, it is subtracted, and a `1` bit is recorded;
otherwise a `0` bit is recorded and the remaining angle is left unchanged. This is
called *pseudo-division* because it works exactly like the compare-and-subtract
restoring division algorithm, just against a table of constants instead of a single
shifted divisor. What is left afterwards is a tiny residual angle, together with a
record of exactly which special angles were used to reduce it:
```math
\theta = \sum_{i=0}^{n-1} q_i \arctan(2^{-i}) + z, \qquad q_i \in \{0, 1\},
```
where $n$ is `G_ITERATIONS`.

**Why the residual is small:** Before step $i$, the remaining angle is less
than $\arctan(2^{-(i-1)})$ (initially $\theta < \frac{\pi}{4} = \arctan(2^0)$).
Since $\arctan(2x) \le 2\arctan(x)$, this is at most $2\arctan(2^{-i})$. So
after step $i$ the remaining angle is less than $\arctan(2^{-i})$, whether the
special angle was subtracted or not. After the last step,
```math
0 \le z < \arctan\left(2^{-(n-1)}\right) < 2^{-(n-1)} .
```
The residual is never negative, since an angle is only subtracted when it
fits.

## Phase 2: Padé approximation
For the tiny residual angle `z`, `tan(z)` is well approximated by the
[Padé approximant](https://en.wikipedia.org/wiki/Pad%C3%A9_approximant)
```math
\tan z \approx \frac{3z}{3 - z^2} .
```
Its error is tiny: $\tan z = z + \frac{z^3}{3} + \frac{2z^5}{15} + \ldots$ and
$\frac{3z}{3 - z^2} = z + \frac{z^3}{3} + \frac{z^5}{9} + \ldots$, so the error is
about $\frac{z^5}{45}$. Rather than performing this division, the numerator
`3z` becomes the initial value of `y`, and the denominator `3 - z*z` becomes the
initial value of `x`. The division is deferred to the very end, where a single
division replaces what would otherwise have taken many more CORDIC iterations.

This phase is split across two clock cycles (`PADE_MUL_ST`, then `PADE_ST`): the
multiplication `z*z` is registered on its own, before it is subtracted from `3` on
the next cycle. This does not change the result; it exists purely to shorten the
longest combinational path (see [Timing](#timing)).

`z` is also narrowed to `small_angle_type` before squaring it, so that the
multiplier is as small as possible:
* **Upper bits:** Since $z < 2^{-(n-1)}$, its bits above that weight are always
  zero and can be dropped. This is lossless.
* **Lower bits:** The square only needs to be precise to about
  $2^{-(F+4)}$, where $F$ is `G_FRAC_BITS`. Truncating $z$ to its bits down to
  weight $2^{-m}$ (an error $e < 2^{-m}$) changes the square by
  $e(2z - e) < 2^{-(m+n-2)}$. Since $x \approx 3$ and $\tan\theta \le 1$, the
  result changes by less than a third of that. With $m = F - n + 4$, this is
  below $2^{-(F+3.6)}$, i.e. less than $\frac{1}{12}$ of the last bit of the
  result. `z` itself (for $3z$) keeps all its bits.

For the default configuration ($n = 6$, $F = 24$), $z$ then has 18 bits (weights
$2^{-5}$ to $2^{-22}$), and the multiplier is 18x18 bits, which fits in a single
`DSP48E1` tile. Without the truncation it would be 28x28 bits, a cascade of four
tiles, which does not meet the timing, see [Timing](#timing). The largest errors
in [Accuracy and the number of iterations](#accuracy-and-the-number-of-iterations)
are the same with and without the truncation.

## Phase 3: Pseudo-multiplication
The `(x, y)` vector is now rotated by exactly the special angles that were used
during phase 1 (i.e. those recorded as `1` bits), applied smallest-angle-first:
```
x := x - y * 2**-i   (whenever bit i was set)
y := y + x * 2**-i
```
Each such step is a rotation by $\arctan(2^{-i})$, combined with a stretch by
$\sqrt{1 + 4^{-i}}$. The initial vector has the angle $\arctan(y_0/x_0) \approx z$,
and the rotations add $\theta - z$, so the final vector has the angle $\theta$.
The stretches change its length, but not the ratio $y/x = \tan\theta$, so, unlike
in the classical CORDIC, no scale factor is needed. Rotations commute, so the
order does not matter mathematically; it only affects the rounding.

The vector starts with a length of about 3, and the stretches multiply it by at
most $\prod_i \sqrt{1 + 4^{-i}} \approx 1.647$, so it stays below about 5.

## Final division
A single restoring division of `y` by `x` produces the final result. Since
`0 <= y <= x` throughout the valid input range, the quotient always lies in
`[0.0, 1.0]`, and one quotient bit is produced per clock cycle, MSB first -- the
same technique as the pseudo-division of phase 1, just against a single (non-tabulated)
divisor. The quotient is truncated to `G_FRAC_BITS` bits.

## Fixed-point representation
This module uses the IEEE `fixed_pkg` package (`ieee.fixed_pkg`), part of VHDL-2008,
for all internal arithmetic:

* The residual angle uses one sign bit and `G_FRAC_BITS + 8` fractional bits.
* The `(x, y)` vector uses three integer bits (it grows from about 3.0 to at most
  about 5.0, see above), one sign bit, and `G_FRAC_BITS + 8` fractional bits.
* The eight extra ("guard") fractional bits limit the build-up of rounding error
  across the three phases; they are discarded before the final result is produced.

## Accuracy and the number of iterations
The Padé approximation makes the iterations very effective. Its error
$\frac{z^5}{45}$, with $z < 2^{-(n-1)}$, is below $2^{-5(n-1) - 5.5}$, i.e. each
iteration gains about 5 bits, not 1 bit as in the classical CORDIC. So the
number of iterations needed for full precision is only about a quarter of
`G_FRAC_BITS`.

Measured with 3000 random angles each, like in the testbench, i.e. against the
tangent of the unrounded angle, but with the Taylor series as the reference
(`tan` of `ieee.math_real` is only accurate to about $2^{-28}$ in GHDL):

| `G_FRAC_BITS` | Iterations   | Largest error |
| ------------- | ------------ | ------------- |
| 8             | 2 to 4       | $2^{-7.0}$    |
| 16            | 3            | $2^{-14.2}$   |
| 16            | 4, 5, 16     | $2^{-15.2}$   |
| 24            | 3            | $2^{-14.9}$   |
| 24            | 4            | $2^{-19.9}$   |
| 24            | 5            | $2^{-22.9}$   |
| 24            | 6 to 20      | $2^{-23.1}$   |
| 28            | 5            | $2^{-24.5}$   |
| 28            | 6            | $2^{-27.0}$   |
| 28            | 7, 8, 16     | $2^{-27.1}$   |

With enough iterations, the error is about two units of the last bit: one from
rounding the angle to `G_FRAC_BITS` bits (the slope of the tangent is up to 2
in $[0, \frac{\pi}{4}]$), and one from truncating the quotient. Against the
tangent of the rounded angle, i.e. the angle that the design actually gets,
the error with 6 iterations (24 bits) or 7 iterations (28 bits) is at most
$2^{-24.0}$ and $2^{-28.0}$, i.e. one unit, the same as with 16 iterations.

So 16 iterations (as in the 8087, which aims at 64 bits) are far more than
needed for `G_FRAC_BITS = 24`, and the design uses 6 by default. This gives
the same accuracy, with a latency of 40 instead of 60 clock cycles (320 instead
of 480 ns). In general, about `G_FRAC_BITS/4` iterations are enough.

The testbench's tolerance follows from this analysis: twice the sum of two
units of the last bit, $2^{1-F}$, and the error of the Padé approximation,
$2 \cdot 2^{-5(n-1)} / 45$ (including the slope of up to 2).

## Timing
A full calculation takes `2*G_ITERATIONS + G_FRAC_BITS + 5` clock cycles (41 for the
default configuration): one cycle to accept the input, `G_ITERATIONS` for
pseudo-division, two for the Padé approximation, `G_ITERATIONS` for
pseudo-multiplication, one to load the divider, `G_FRAC_BITS` for the final division,
and one to hold the result until it is consumed. The result is valid (`m_valid_o`
high) 40 clock cycles after the clock cycle where the input is accepted.

Synthesized, placed and routed with Vivado 2025.1 for `xc7a200tfbg484-2` (the part
used elsewhere in this repo), out-of-context, at the default configuration, with
`make vivado`. The current version meets the 8 ns clock constraint in
`tan_cordic.xdc` with a slack of 0.782 ns. The three earlier versions are from the git
history, with 16 iterations. The first two (commits 677aa4e and 59e9417) are
implemented the same way, but with a clock period of 14 ns and 11 ns, which they meet
with a slack of 0.535 ns and 0.291 ns. The critical path is the clock period minus the
slack, and the wall time is the critical path times the number of clock cycles per
calculation (60 for the original version, 61 for the next two, and 41 for the current
version). The Slice LUTs are from `utilization.rpt`. The summary printed by
`make vivado` counts LUT cells instead, which is higher (691 for the current version),
since two LUT cells can share one slice LUT:

| | Slice LUTs | Registers | DSP48E1 | Critical path | Fmax | Wall time/calc |
| --- | --- | --- | --- | --- | --- | --- |
| Original (single-cycle Padé) | 624 | 254 | 4 | 13.47 ns | ~74 MHz | ~808 ns |
| Split Padé (`PADE_MUL_ST` + `PADE_ST`) | 826 | 333 | 4 | 10.71 ns | ~93 MHz | ~653 ns |
| ...and narrowed `z*z` multiplier | 561 | 282 | 1 | 7.68 ns | ~130 MHz | ~468 ns |
| ...and 6 instead of 16 iterations (current) | 556 | 310 | 1 | 7.22 ns | ~139 MHz | ~296 ns |

Splitting the Padé phase across two cycles removes the multiplier from the same
combinational path as the following 36-bit-wide subtraction, at the cost of one
extra clock cycle (60 -> 61). Narrowing `z` before squaring it then removes the
two-tile `DSP48E1` cascade entirely (down to a single tile), at no extra cost in
cycles, LUTs, or registers -- if anything it uses fewer of each, since the
multiplier and its registers are themselves smaller. The two changes together
bring wall time down by about 42%, using fewer LUTs and DSPs than the original
version, at the cost of 28 more registers.

Reducing the number of iterations from 16 to 6, see
[Accuracy and the number of iterations](#accuracy-and-the-number-of-iterations),
saves 20 clock cycles. But it makes the residual angle $z$ larger (up to $2^{-5}$
instead of $2^{-15}$), so the multiplier for $z^2$ grew to 28x28 bits, a cascade of
four `DSP48E1` tiles, and the design missed the 8 ns constraint by 4.85 ns. Truncating
the lower bits of $z$ before squaring it (see
[Phase 2](#phase-2-padé-approximation)) brings the multiplier back to 18x18 bits and a
single tile, without changing the accuracy. Altogether, the wall time is now about
63% lower than in the original version.

The remaining critical path still runs into `zz_reg`, but the next paths are only
about 0.8 to 1.4 ns behind, and there are several of them: into `x` (the
pseudo-multiplication add/subtract in `ROTATE_ST`), into `rem_reg` (the restoring
division in `DIVIDE_ST`), and into `angle` (the compare-and-subtract of the
pseudo-division in `REDUCE_ST`). Closing that gap further would mean pipelining
all three iterative phases (e.g. splitting the shift and the add/subtract of
`ROTATE_ST` across two cycles), which -- unlike the changes above -- would add one
extra cycle *per iteration* (about `2*G_ITERATIONS + G_FRAC_BITS` more cycles in
total), a much larger latency cost for a smaller, less clear-cut potential gain.
That trade-off has not been attempted here.

Utilization remains well under 1% of the device throughout.
