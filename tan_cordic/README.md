# Tangent CORDIC

This calculates `tan(angle)` for `angle` in the range `[0.0, pi/4[`, using a hardware
adaptation of the algorithm used by the Intel 8087 math co-processor, as described in
[this article](https://www.righto.com/2026/09/8087-tangent-cordic.html).

## Interface
Both input and output use an AXI-style VALID/READY handshake:

* The input angle `s_angle_i` uses the handshake signals `s_valid_i` and `s_ready_o`.
* The result `m_tan_o` uses the handshake signals `m_valid_o` and `m_ready_i`.

The angle and the result are both unsigned fixed-point numbers with `G_FRAC_BITS`
fractional bits and no integer bits, i.e. `value = bits / 2**G_FRAC_BITS`. The input
must satisfy `0.0 <= angle < pi/4`; the output then satisfies `0.0 <= tan(angle) < 1.0`.

Only one calculation is in flight at a time: a new angle is accepted only once the
module has returned to idle, which happens only after the previous result has been
consumed (i.e. this module does not overlap consecutive calculations, unlike e.g.
`booth`).

## Theory of operation
The classical CORDIC algorithm calculates `sin` and `cos` by rotating the vector
`(1, 0)` by the target angle, one step at a time, using only additions, subtractions,
and shifts. Each step either adds or subtracts a special angle `arctan(2**-i)`, chosen
so that the correction shrinks the remaining angle at every step, regardless of its
sign. Because tangent is just `sin/cos = y/x`, and this ratio does not depend on the
length of the vector, the usual CORDIC scale-factor correction can be skipped
entirely when only the tangent is wanted.

Doing this angle-by-angle correction for a full 64-bit result would need 64
iterations. To get a fast result with only `G_ITERATIONS` (e.g. 16) iterations, this
module (like the 8087) instead splits the calculation into three phases:

### Phase 1: Pseudo-division
The input angle is repeatedly compared against a table of decreasing special angles
`arctan(2**-i)`, for `i = 0 .. G_ITERATIONS-1`. Whenever the current special angle
fits inside the remaining angle, it is subtracted, and a `1` bit is recorded;
otherwise a `0` bit is recorded and the remaining angle is left unchanged. This is
called *pseudo-division* because it works exactly like the compare-and-subtract
restoring division algorithm, just against a table of constants instead of a single
shifted divisor. What is left afterwards is a tiny residual angle, together with a
record of exactly which special angles were used to reduce it.

### Phase 2: Padé approximation
For the tiny residual angle `z`, `tan(z)` is well approximated by the Padé
approximant

```
tan(z) = 3z / (3 - z*z)
```

which has an error proportional to `z**4`. Since `z` is tiny (on the order of
`2**-G_ITERATIONS`), this is far more accurate than the CORDIC part itself, so it
does not limit the overall accuracy. Rather than performing this division, the
numerator `3z` becomes the initial value of `y`, and the denominator `3 - z*z`
becomes the initial value of `x`. The division is deferred to the very end, where a
single division replaces what would otherwise have taken many more CORDIC
iterations.

### Phase 3: Pseudo-multiplication
The `(x, y)` vector is now rotated by exactly the special angles that were used
during phase 1 (i.e. those recorded as `1` bits), applied smallest-angle-first:

```
x := x - y * 2**-i   (whenever bit i was set)
y := y + x * 2**-i
```

Since these are exactly the angles that were subtracted from the original input
angle during phase 1, replaying them (in either order, since these operations
commute) reconstructs a vector `(x, y)` such that `y / x = tan(angle)`.

### Final division
A single restoring division of `y` by `x` produces the final result. Since
`0 <= y <= x` throughout the valid input range, the quotient always lies in
`[0.0, 1.0]`, and one quotient bit is produced per clock cycle, MSB first -- the
same technique as the pseudo-division of phase 1, just against a single (non-tabulated)
divisor.

## Fixed-point representation
This module uses the IEEE `fixed_pkg` package (`ieee.fixed_pkg`), part of VHDL-2008,
for all internal arithmetic:

* The residual angle uses one sign bit and `G_FRAC_BITS + 8` fractional bits.
* The `(x, y)` vector uses three integer bits (it grows from about 3.0 to at most
  about 5.0, since the CORDIC gain factor for a full set of iterations is about
  1.647), one sign bit, and `G_FRAC_BITS + 8` fractional bits.
* The eight extra ("guard") fractional bits limit the build-up of rounding error
  across the three phases; they are discarded before the final result is produced.

## Simulation
The script `sim.sh` runs the testbench `tb_tan_cordic.vhd` using GHDL (`--std=08`).
The testbench generates angles uniformly distributed in `[0.0, pi/4[`, plus a few
fixed corner cases (zero, and angles just below `pi/4`), and randomly stalls both the
VALID and READY signals. It:

* Sweeps `G_ITERATIONS` from 4 to 20 and `G_FRAC_BITS` from 8 to 28.
* Verifies accuracy against `ieee.math_real.tan`, with a tolerance that scales with
  `min(G_ITERATIONS, G_FRAC_BITS)`.
* Runs a larger (5000-sample) test at the default configuration
  (`G_ITERATIONS => 16`, `G_FRAC_BITS => 24`).
* Checks operation without stalls, and with a slow consumer or a slow producer.

With the default configuration, the maximum observed error across 5000 random angles
is below `2**-22`, i.e. close to the full `G_FRAC_BITS` (24) of accuracy -- somewhat
better than the 8087's own "roughly 16 bits" for its 16-iteration CORDIC part, mostly
thanks to the guard bits and to `G_FRAC_BITS` (24) being smaller than what the real
8087 was aiming for (64 bits).

## Links
* [https://www.righto.com/2026/09/8087-tangent-cordic.html](https://www.righto.com/2026/09/8087-tangent-cordic.html)
* [https://en.wikipedia.org/wiki/CORDIC](https://en.wikipedia.org/wiki/CORDIC)
