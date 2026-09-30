# Tangent CORDIC

This calculates `tan(angle)` for `angle` in the range `[0.0, pi/4[`, using a hardware
adaptation of the algorithm used by the Intel 8087 math co-processor, as described in
[this article](https://www.righto.com/2026/09/8087-tangent-cordic.html).

The latency is 320 ns with the default configuration, at the 125 MHz clock
constraint in [`tan_cordic.xdc`](tan_cordic.xdc). With 32 bits it is 478 ns, at
108.7 MHz, see [Timing](#timing).

## The algorithm
The classical CORDIC algorithm calculates `sin` and `cos` by rotating a vector by the
target angle, one small special angle `arctan(2**-i)` at a time, using only
additions, subtractions, and shifts. Since the tangent is just `y/x`, the length of
the vector does not matter, and the usual CORDIC scale factor is not needed. Like
the 8087, this module splits the calculation into three phases:

1. **Pseudo-division:** The angle is written as a sum of `G_ITERATIONS` special
   angles `arctan(2**-i)` (each used or not), plus a tiny residual angle `z`.
2. **Padé approximation:** `tan(z)` is approximated by `3z / (3 - z*z)`, whose
   numerator and denominator become the initial vector `(x, y)`.
3. **Pseudo-multiplication:** The vector is rotated by the special angles used in
   phase 1. Then `y/x = tan(angle)`.

Finally, a restoring division calculates `y/x`, one bit per clock cycle.

[ALGORITHM.md](ALGORITHM.md) explains the algorithm in detail: why each phase
works, the fixed-point representation, how the accuracy depends on the number of
iterations (about `G_FRAC_BITS/4` iterations are enough for full precision, since
the Padé approximation gains about 5 bits per iteration), and the timing.

## Files
| File | Description
| ---- | -----------
| [`tan_cordic.vhd`](tan_cordic.vhd) | The tangent CORDIC.
| [`tb_tan_cordic.vhd`](tb_tan_cordic.vhd) | Testbench.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm, the accuracy, and the timing.
| [`tan_cordic.gtkw`](tan_cordic.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`tan_cordic.xdc`](tan_cordic.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (125 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`Makefile`](Makefile) | Runs the simulation and the synthesis, see [Running](#running).

## Interface
The generic `G_ITERATIONS` is the number of CORDIC iterations (default 6; the 8087
uses up to 16, for 64 bits), and `G_FRAC_BITS` is the number of fractional bits of the
angle and the result (default 24). About `G_FRAC_BITS/4` iterations give full
precision, see
[Accuracy and the number of iterations](ALGORITHM.md#accuracy-and-the-number-of-iterations).

Both the input and the output use an
[AXI](https://en.wikipedia.org/wiki/Advanced_eXtensible_Interface)-style
VALID/READY handshake: a value is transferred in a clock cycle where both valid
and ready are high. The sender keeps valid high and the value unchanged until
then.

| Port | Direction | Description
| ---- | --------- | -----------
| `clk_i` | in | Clock.
| `rst_i` | in | Synchronous reset, active high. Clears `m_valid_o`, and abandons a calculation in progress.
| `s_valid_i`, `s_ready_o` | in, out | Handshake of the input.
| `s_angle_i` | in | The angle, in radians.
| `m_valid_o`, `m_ready_i` | out, in | Handshake of the output.
| `m_tan_o` | out | The result, `tan(angle)`.

None of the output signals depend combinatorially on any of the input signals.

The angle and the result are both unsigned fixed-point numbers with `G_FRAC_BITS`
fractional bits and no integer bits, i.e. `value = bits / 2**G_FRAC_BITS`. The input
must satisfy `0.0 <= angle < pi/4`; the output then satisfies `0.0 <= tan(angle) < 1.0`.

Only one calculation is in flight at a time: a new angle is accepted only once the
module has returned to idle, which happens only after the previous result has been
consumed (i.e. this module does not overlap consecutive calculations, unlike e.g.
[`booth`](../booth)).

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench (see [below](#simulation)). This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 10 seconds.
  E.g. `make sim ITERATIONS=6 FRAC_BITS=24` sweeps only that configuration
  (the fixed runs listed below are always included).
* `make debug` runs a short simulation (20 tangents) with the default
  configuration, and writes a waveform to `tan_cordic.ghw`. Use `make show_debug`
  to view it in [GTKWave](https://github.com/gtkwave/gtkwave), with the signals
  selected in `tan_cordic.gtkw`.
* `make vivado` synthesizes and implements `tan_cordic.vhd` with the default
  configuration, using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
  for the Artix-7 part xc7a200tfbg484-2. The design is implemented out of
  context, i.e. as a module inside a larger design, so only the paths between
  registers are timed. It fails if the design does not meet the 125 MHz clock
  constraint in `tan_cordic.xdc`. At the end it prints the number of cells and the
  slack, logic levels, start point and end point of the worst path, and the reports
  are written to `vivado/tan_cordic_6_24/`. E.g.
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

* Sweeps `G_ITERATIONS` over 2, 4, 6, 8, 16, and 20, and `G_FRAC_BITS` over 8, 16,
  20, 24, 28, and 32, with 150 angles for each of the 36 combinations.
* Verifies accuracy against the tangent calculated with the Taylor series (the `tan`
  of `ieee.math_real` is only accurate to about `2**-28` in GHDL), with a tolerance
  from the error analysis in
  [Accuracy and the number of iterations](ALGORITHM.md#accuracy-and-the-number-of-iterations):
  twice the sum of two units of the last bit and the error of the Padé
  approximation.
* Runs a larger (5000-sample) test at the default configuration
  (`G_ITERATIONS => 6`, `G_FRAC_BITS => 24`).
* Checks operation without stalls, and with a slow consumer or a slow producer (ready
  or valid in only 10% of the clock cycles), with 500 angles each.

With the default configuration, the largest error is about `2**-23.1`, i.e. two units
of the last bit: one from rounding the angle to 24 bits, and one from truncating the
quotient. More iterations do not reduce it.

## Timing
A full calculation takes `2*G_ITERATIONS + G_FRAC_BITS + 5` clock cycles (41 for the
default configuration), and the result is valid 40 clock cycles after the input is
accepted. The design meets the 8 ns clock constraint in `tan_cordic.xdc` with a slack
of 0.782 ns, using 556 Slice LUTs, 310 registers, and one DSP48E1.
[Timing](ALGORITHM.md#timing) describes how the critical path was shortened, and how
the number of iterations was reduced from 16 to 6.

With `G_FRAC_BITS => 32`, full precision needs 8 iterations: the largest error is
about `2**-31.2`, and against the tangent of the rounded angle it is one unit of the
last bit, `2**-32.0`, the same as with 16 iterations. A calculation then takes 53
clock cycles, and the result is valid 52 clock cycles after the input is accepted.
The design does not meet the 8 ns clock constraint (the slack is -0.921 ns), since the
multiplier for `z*z` is wider, see [Phase 2](ALGORITHM.md#phase-2-padé-approximation).
It meets a clock period of 9.2 ns (108.7 MHz) with a slack of 0.044 ns, using 766
Slice LUTs, 379 registers, and one DSP48E1, so the latency is 478 ns. With 7
iterations the largest error is slightly larger, `2**-31.1` (`2**-31.8` against the
rounded angle), but the design meets a clock period of 8.5 ns (117.6 MHz) with a slack
of 0.113 ns, using 685 Slice LUTs, 384 registers, and two DSP48E1. Then the latency is
50 clock cycles, i.e. 425 ns. To check this, change the clock period in
`tan_cordic.xdc`, and run e.g. `make vivado VIVADO_ITERATIONS=8 VIVADO_FRAC_BITS=32`.

## Links
* [https://www.righto.com/2026/09/8087-tangent-cordic.html](https://www.righto.com/2026/09/8087-tangent-cordic.html)
* [https://en.wikipedia.org/wiki/CORDIC](https://en.wikipedia.org/wiki/CORDIC)
