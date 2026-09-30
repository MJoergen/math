# Tangent CORDIC

This calculates `tan(angle)` for `angle` in the range `[0.0, pi/4[`, using a hardware
adaptation of the algorithm used by the Intel 8087 math co-processor, as described in
[this article](https://www.righto.com/2026/09/8087-tangent-cordic.html).

## Files
| File | Description
| ---- | -----------
| [`tan_cordic.vhd`](tan_cordic.vhd) | The tangent CORDIC.
| [`tb_tan_cordic.vhd`](tb_tan_cordic.vhd) | Testbench.
| [`tan_cordic.xdc`](tan_cordic.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (125 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`Makefile`](Makefile) | Runs the simulation and the synthesis, see [Running](#running).

## Interface
| Name | Kind | Description
| ---- | ---- | -----------
| `G_ITERATIONS` | generic | The number of CORDIC iterations, default 16 (as the 8087).
| `G_FRAC_BITS` | generic | The number of fractional bits of the angle and the result, default 24.
| `clk_i` | in | Clock.
| `rst_i` | in | Synchronous reset, active high.
| `s_valid_i`, `s_ready_o`, `s_angle_i` | in, out, in | The input angle, in radians.
| `m_valid_o`, `m_ready_i`, `m_tan_o` | out, in, out | The result, `tan(angle)`.

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

This phase is split across two clock cycles (`PADE_MUL_ST`, then `PADE_ST`): the
multiplication `z*z` is registered on its own, before it is subtracted from `3` on
the next cycle. This does not change the result; it exists purely to shorten the
longest combinational path (see "Timing" below).

`z` is also narrowed to `small_angle_t` before squaring it. After the last
pseudo-division iteration, `z` is always strictly less than
`arctan(2**-(G_ITERATIONS-1)) < 2**-(G_ITERATIONS-1)`, so its bits above that
weight are provably always zero and can be dropped -- for the default
configuration this shrinks the multiplier from 33x33 bits down to 18x18 bits,
which fits in a single `DSP48E1` tile instead of a two-tile cascade. This too is
lossless; it only removes bits that were always zero.

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

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench (see [below](#simulation)). This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 10 seconds.
  E.g. `make sim ITERATIONS=16 FRAC_BITS=24` sweeps only that configuration
  (the fixed runs listed below are always included).
* `make debug` runs a short simulation (20 tangents) with the default
  configuration, and writes a waveform to `tan_cordic.ghw`. Use `make show_debug`
  to view it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make vivado` synthesizes and implements `tan_cordic.vhd` with the default
  configuration, using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
  for the Artix-7 part xc7a200tfbg484-2. The design is implemented out of
  context, i.e. as a module inside a larger design, so only the paths between
  registers are timed. It fails if the design does not meet the 125 MHz clock
  constraint in `tan_cordic.xdc`. At the end it prints the number of cells and the
  slack, logic levels, start point and end point of the worst path, and the reports
  are written to `vivado/tan_cordic_16_24/`. E.g.
  `make vivado VIVADO_ITERATIONS=8 VIVADO_FRAC_BITS=16` selects other generics. It
  takes about 2 minutes, and expects Vivado in `/opt/Xilinx/2025.1/Vivado` (the
  variable `XILINX_DIR`).
* `make clean` removes the generated files.

## Simulation
`make sim` runs the testbench `tb_tan_cordic.vhd` using GHDL (`--std=08`).
The testbench generates angles uniformly distributed in `[0.0, pi/4[`, plus a few
fixed corner cases (zero, an angle just below `pi/4`, and a very small angle), and
randomly stalls both the VALID and READY signals. It stops at the first result that is
outside the tolerance. It:

* Sweeps `G_ITERATIONS` over 4, 8, 12, 16, and 20, and `G_FRAC_BITS` over 8, 16, 20,
  24, and 28, with 150 angles for each of the 25 combinations.
* Verifies accuracy against `ieee.math_real.tan`, with a tolerance that scales with
  `min(G_ITERATIONS, G_FRAC_BITS)`.
* Runs a larger (5000-sample) test at the default configuration
  (`G_ITERATIONS => 16`, `G_FRAC_BITS => 24`).
* Checks operation without stalls, and with a slow consumer or a slow producer (ready
  or valid in only 10% of the clock cycles), with 500 angles each.

With the default configuration, the maximum observed error across 5000 random angles
is below `2**-22`, i.e. close to the full `G_FRAC_BITS` (24) of accuracy -- somewhat
better than the 8087's own "roughly 16 bits" for its 16-iteration CORDIC part, mostly
thanks to the guard bits and to `G_FRAC_BITS` (24) being smaller than what the real
8087 was aiming for (64 bits).

## Timing
A full calculation takes `2*G_ITERATIONS + G_FRAC_BITS + 5` clock cycles (61 for the
default configuration): one cycle to accept the input, `G_ITERATIONS` for
pseudo-division, two for the Padé approximation, `G_ITERATIONS` for
pseudo-multiplication, one to load the divider, `G_FRAC_BITS` for the final division,
and one to hold the result until it is consumed. The result is valid (`m_valid_o`
high) 60 clock cycles after the clock cycle where the input is accepted.

Synthesized, placed and routed with Vivado 2025.1 for `xc7a200tfbg484-2` (the part
used elsewhere in this repo), out-of-context, at the default configuration, with
`make vivado`. The current version meets the 8 ns clock constraint in
`tan_cordic.xdc` with a slack of 0.320 ns. The two earlier versions are from the git
history (commits 677aa4e and 59e9417), implemented the same way, but with a clock
period of 14 ns and 11 ns, which they meet with a slack of 0.535 ns and 0.291 ns. The
critical path is the clock period minus the slack, and the wall time is the critical
path times the number of clock cycles per calculation (60 for the original version,
61 for the others). The Slice LUTs are from `utilization.rpt`. The summary printed by
`make vivado` counts LUT cells instead, which is higher (662 for the current version),
since two LUT cells can share one slice LUT:

| | Slice LUTs | Registers | DSP48E1 | Critical path | Fmax | Wall time/calc |
| --- | --- | --- | --- | --- | --- | --- |
| Original (single-cycle Padé) | 624 | 254 | 4 | 13.47 ns | ~74 MHz | ~808 ns |
| Split Padé (`PADE_MUL_ST` + `PADE_ST`) | 826 | 333 | 4 | 10.71 ns | ~93 MHz | ~653 ns |
| ...and narrowed `z*z` multiplier (current) | 561 | 282 | 1 | 7.68 ns | ~130 MHz | ~468 ns |

Splitting the Padé phase across two cycles removes the multiplier from the same
combinational path as the following 36-bit-wide subtraction, at the cost of one
extra clock cycle (60 -> 61). Narrowing `z` before squaring it then removes the
two-tile `DSP48E1` cascade entirely (down to a single tile), at no extra cost in
cycles, LUTs, or registers -- if anything it uses fewer of each, since the
multiplier and its registers are themselves smaller. The two changes together
bring wall time down by about 42%, using fewer LUTs and DSPs than the original
version, at the cost of 28 more registers.

The remaining critical path still runs into `zz_reg`, but only just: the next paths
are about 1.3 to 1.4 ns behind, and there are several of them: into `angle` (the
compare-and-subtract of the pseudo-division in `REDUCE_ST`), into `x` (the
pseudo-multiplication add/subtract in `ROTATE_ST`), and into `rem_reg` (the
restoring division in `DIVIDE_ST`). Closing that gap further would mean pipelining
all three iterative phases (e.g. splitting the shift and the add/subtract of
`ROTATE_ST` across two cycles), which -- unlike the changes above -- would add one
extra cycle *per iteration* (about `2*G_ITERATIONS + G_FRAC_BITS` more cycles in
total), a much larger latency cost for a smaller, less clear-cut potential gain.
That trade-off has not been attempted here.

Utilization remains well under 1% of the device throughout.

## Links
* [https://www.righto.com/2026/09/8087-tangent-cordic.html](https://www.righto.com/2026/09/8087-tangent-cordic.html)
* [https://en.wikipedia.org/wiki/CORDIC](https://en.wikipedia.org/wiki/CORDIC)
