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
A single division of `y` by `x` produces the final result. Since `0 <= y <= x`
throughout the valid input range, the quotient always lies in `[0.0, 1.0]`, and one
quotient bit is produced per iteration, MSB first. The quotient is truncated to
`G_FRAC_BITS` bits.

The division is non-restoring: Each iteration doubles the remainder $r$, and
subtracts $x$ if $r \ge 0$, or adds $x$ if $r < 0$. The quotient bit is 1 if the new
remainder is not negative. A restoring division would instead add $x$ back to a
negative remainder before the next iteration (or, equivalently, keep the remainder
from before the subtraction), and then subtract $x$ again. Since
$2(r + x) - x = 2r + x$, both give the same remainder whenever the restoring division
keeps it, and so the same quotient bits. But each iteration is a single addition or
subtraction, instead of a subtraction followed by a multiplexer. The remainder stays
in $[-x, x]$.

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
| 32            | 5            | $2^{-24.5}$   |
| 32            | 6            | $2^{-29.2}$   |
| 32            | 7            | $2^{-31.1}$   |
| 32            | 8, 16        | $2^{-31.2}$   |

With enough iterations, the error is about two units of the last bit: one from
rounding the angle to `G_FRAC_BITS` bits (the slope of the tangent is up to 2
in $[0, \frac{\pi}{4}]$), and one from truncating the quotient. Against the
tangent of the rounded angle, i.e. the angle that the design actually gets,
the error with 6 iterations (24 bits), 7 iterations (28 bits), or 8 iterations
(32 bits) is at most $2^{-24.0}$, $2^{-28.0}$, and $2^{-32.0}$, i.e. one unit,
the same as with 16 iterations.

So 16 iterations (as in the 8087, which aims at 64 bits) are far more than
needed for `G_FRAC_BITS = 24`, and the design uses 6 by default. This gives
the same accuracy, with a latency of 40 instead of 60 clock cycles (320 instead
of 480 ns). In general, about `G_FRAC_BITS/4` iterations are enough.

The testbench's tolerance follows from this analysis: twice the sum of two
units of the last bit, $2^{1-F}$, and the error of the Padé approximation,
$2 \cdot 2^{-5(n-1)} / 45$ (including the slope of up to 2).

## Timing
With $k$ = `G_STEPS`, the result is valid (`m_valid_o` high)
$2\lceil n/k \rceil + \lceil F/k \rceil + 3$ clock cycles after the clock cycle
where the input is accepted: $\lceil n/k \rceil$ for pseudo-division, two for the
Padé approximation, $\lceil n/k \rceil$ for pseudo-multiplication, and
$\lceil F/k \rceil$ for the final division. The final `x` and `y` are loaded into
the divider directly in the last clock cycle of pseudo-multiplication. A full
calculation takes one more clock cycle, to hold the result until it is consumed. For
the default configuration ($n = 6$, $F = 24$, $k = 4$), the latency is 13 clock
cycles.

### Several iterations in each clock cycle
Pseudo-division, pseudo-multiplication, and the division each do `G_STEPS`
iterations in each clock cycle. If `G_STEPS` does not divide $n$ or $F$, the last
clock cycle of a phase does fewer iterations. In all three, each iteration depends on
the previous one, so the iterations of a clock cycle are in series. Three details keep
each iteration short:
* The division is non-restoring, see [Final division](#final-division), so each
  iteration is a single carry chain.
* The additions and subtractions in the iterations use `resize` with `fixed_wrap`
  and `fixed_truncate`. The default of `resize` is to saturate and to round, which
  adds logic after each carry chain. The values never overflow, and no bits are
  rounded away, so the result is the same. With the defaults, each iteration of the
  division took about 4.1 ns instead of about 2.6 ns.
* In pseudo-multiplication, iteration $j$ of the clock cycle `count` shifts by
  $n - 1 - (\mathtt{count} \cdot k + j)$ bits. Since `count` only has
  $\lceil n/k \rceil$ values, each shift is a multiplexer with only that many
  inputs.

The result is the same, bit for bit, for all values of `G_STEPS`, and the same as in
the earlier version with one iteration in each clock cycle and a restoring division
(checked with random angles for many values of $n$, $F$, and $k$).

The latency for each value of `G_STEPS`, from `make vivado`, with the clock period
in `tan_cordic.xdc` reduced until the timing was no longer met. The clock period is
the shortest one where the timing is met, and the next shorter one that was tried (in
parentheses) does not meet the timing. The LUTs and flip-flops are the numbers that
`make vivado` prints:

| `G_STEPS` | 24 bits, 6 iterations: Clock cycles | Clock period | Latency | LUT | FF |
| --------- | ---- | ------------------ | ------ | ---- | --- |
| 1         | 39   | 5.75 ns (5.5 ns)   | 224 ns |  629 | 305 |
| 2         | 21   | 7.75 ns (7.5 ns)   | 163 ns |  887 | 303 |
| 3         | 15   | 9.0 ns (8.75 ns)   | 135 ns | 1075 | 336 |
| 4         | 13   | 11.5 ns (11.25 ns) | 150 ns | 1348 | 335 |
| 8         | 8    | 21.0 ns (20.5 ns)  | 168 ns | 2066 | 295 |

| `G_STEPS` | 32 bits, 8 iterations: Clock cycles | Clock period | Latency | LUT | FF |
| --------- | ---- | ------------------ | ------ | ---- | --- |
| 1         | 51   | 9.5 ns (9.2 ns)    | 485 ns |  823 | 378 |
| 2         | 27   | 9.5 ns (9.0 ns)    | 257 ns | 1196 | 373 |
| 3         | 20   | 11.5 ns (11.0 ns)  | 230 ns | 2042 | 416 |
| 4         | 15   | 12.5 ns (12.0 ns)  | 188 ns | 1840 | 369 |
| 8         | 9    | 24.5 ns (24.0 ns)  | 221 ns | 3180 | 403 |

Each iteration takes about 2.5 to 3 ns. With `G_STEPS` of 1 (and 2, for 32 bits),
the multiplication `z*z` in `PADE_MUL_ST` is the critical path instead. For 24 bits,
`G_STEPS=3` gives the lowest latency, since 3 divides both 6 and 24, and for 32 bits
`G_STEPS=4`. The default is `G_STEPS=4`, and the constraint in `tan_cordic.xdc` is
11.5 ns (87.0 MHz), which the default configuration meets with a slack of 0.211 ns,
using 1212 Slice LUTs, 335 registers, and one `DSP48E1`. The critical path then runs
through the four pseudo-division iterations, with 25 logic levels.

### Earlier versions
The earlier versions below are from the git history, with one iteration in each clock
cycle, at the default configuration (with 16 iterations for the first three). The first
two (commits 677aa4e and 59e9417) were implemented the same way as the current
version, but with a clock period of 14 ns and 11 ns, which they met with a slack of
0.535 ns and 0.291 ns. The next two met a clock period of 8 ns. The critical path is
the clock period minus the slack (for the last two versions: of the shortest clock
period that was met), and the wall time is the critical path times the number of clock
cycles per calculation (60 for the original version, 61 for the next two, 41 for the
fourth, 40 for the fifth, and 14 for the current version). The Slice LUTs are from
`utilization.rpt`. The summary printed by `make vivado` counts LUT cells instead, which
is higher, since two LUT cells can share one slice LUT:

| | Slice LUTs | Registers | DSP48E1 | Critical path | Fmax | Wall time/calc |
| --- | --- | --- | --- | --- | --- | --- |
| Original (single-cycle Padé) | 624 | 254 | 4 | 13.47 ns | ~74 MHz | ~808 ns |
| Split Padé (`PADE_MUL_ST` + `PADE_ST`) | 826 | 333 | 4 | 10.71 ns | ~93 MHz | ~653 ns |
| ...and narrowed `z*z` multiplier | 561 | 282 | 1 | 7.68 ns | ~130 MHz | ~468 ns |
| ...and 6 instead of 16 iterations | 556 | 310 | 1 | 7.22 ns | ~139 MHz | ~296 ns |
| ...and non-restoring division, wrapped arithmetic, no `LOAD_DIV_ST` (`G_STEPS=1`) | 520 | 305 | 1 | 5.61 ns | ~178 MHz | ~224 ns |
| ...and `G_STEPS=4` (current) | 1212 | 335 | 1 | 11.29 ns | ~89 MHz | ~158 ns |

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

With 6 iterations and one iteration in each clock cycle, the critical path ran into
`zz_reg`, but the next paths were only about 0.8 to 1.4 ns behind: into `x` (the
pseudo-multiplication in `ROTATE_ST`), into `rem_reg` (the division in `DIVIDE_ST`),
and into `angle` (the pseudo-division in `REDUCE_ST`). Pipelining these would have
added clock cycles to every iteration. Instead, several iterations in each clock
cycle (see above) share the fixed overhead of a clock cycle (the clock-to-output
delay, the setup time, and the routing), which reduces the latency by about 50% from
the version with 6 iterations, at the cost of about twice as many LUTs.

Utilization remains well under 1% of the device throughout.
