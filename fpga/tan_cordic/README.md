# Tangent CORDIC

This calculates `tan(angle)` for `angle` in the range `[0.0, pi/4[`, using a hardware
adaptation of the algorithm used by the Intel 8087 math co-processor, as described in
[this article](https://www.righto.com/2026/09/8087-tangent-cordic.html).

The latency is 150 ns (13 clock cycles) with the default configuration, at the
87.0 MHz clock constraint in [`tan_cordic.xdc`](tan_cordic.xdc). With 32 bits it
is 188 ns (15 clock cycles), at 80.0 MHz, see [Timing](#timing).

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

Finally, a non-restoring division calculates `y/x`, one bit per iteration.

Phases 1 and 3, and the division, each do `G_STEPS` iterations (default 4) in
each clock cycle.

[ALGORITHM.md](ALGORITHM.md) explains the algorithm in detail: why each phase
works, the fixed-point representation, how the accuracy depends on the number of
iterations (about `G_FRAC_BITS/4` iterations are enough for full precision, since
the Padé approximation gains about 5 bits per iteration), and the timing for each
value of `G_STEPS`.

## Files
| File | Description
| ---- | -----------
| [`tan_cordic.vhd`](tan_cordic.vhd) | The tangent CORDIC.
| [`tb_tan_cordic.vhd`](tb_tan_cordic.vhd) | Testbench.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm, the accuracy, and the timing.
| [`tan_cordic.gtkw`](tan_cordic.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`tan_cordic.xdc`](tan_cordic.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (87.0 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`tan_cordic.psl`](tan_cordic.psl), [`tan_cordic_bmc.psl`](tan_cordic_bmc.psl), [`tan_cordic.sby`](tan_cordic.sby) | Formal verification, see [Formal verification](#formal-verification).
| [`Makefile`](Makefile) | Runs the simulation, the formal verification, and the synthesis, see [Running](#running).

## Interface
The generic `G_ITERATIONS` is the number of CORDIC iterations (default 6; the 8087
uses up to 16, for 64 bits), and `G_FRAC_BITS` is the number of fractional bits of the
angle and the result (default 24). About `G_FRAC_BITS/4` iterations give full
precision, see
[Accuracy and the number of iterations](ALGORITHM.md#accuracy-and-the-number-of-iterations).
`G_STEPS` is the number of iterations of phases 1 and 3, and of quotient bits of the
division, in each clock cycle (default 4), see [Timing](#timing). It does not change
the result.

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
  [GHDL](https://github.com/ghdl/ghdl). It takes about 30 seconds.
  E.g. `make sim ITERATIONS=6 FRAC_BITS=24 STEPS=4` sweeps only that configuration
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
  registers are timed. It fails if the design does not meet the 87.0 MHz clock
  constraint in `tan_cordic.xdc`. At the end it prints the number of cells and the
  slack, logic levels, start point and end point of the worst path, and the reports
  are written to `vivado/tan_cordic_6_24_4/`. E.g.
  `make vivado VIVADO_ITERATIONS=8 VIVADO_FRAC_BITS=16 VIVADO_STEPS=2` selects other
  generics (which may need another clock constraint, see [Timing](#timing)). It
  takes about 2 minutes, and expects Vivado in `/opt/Xilinx/2025.1/Vivado` (the
  variable `XILINX_DIR`).
* `make formal` runs the formal verification (see [below](#formal-verification)).
  This requires [SymbiYosys](https://github.com/YosysHQ/sby), the
  [GHDL plugin](https://github.com/ghdl/ghdl-yosys-plugin) for Yosys, and the
  [Boolector](https://github.com/Boolector/boolector) solver. It takes about 6
  minutes (most of it for `G_STEPS=2` with the default generics). If it fails,
  use `make show_prove TASK=prove` or `make show_induct TASK=prove` to view the
  counterexample in GTKWave, where the task is one of those in `tan_cordic.sby`.
* `make clean` removes the generated files.

The CI (`.github/workflows/tan_cordic.yml`) runs `make sim` and `make formal`
on every pull request, and every push to master, that changes this directory.

## Formal verification
The formal verification (`tan_cordic.psl`, `tan_cordic.sby`) proves with
k-induction, i.e. for every sequence of inputs and stalls, including resets:
* The result stays valid and unchanged until it is taken, and a new angle is
  only accepted when no result is waiting.
* The result is valid exactly
  `2*ceil(G_ITERATIONS/G_STEPS) + ceil(G_FRAC_BITS/G_STEPS) + 3` clock cycles
  after the angle is accepted (see [Timing](#timing)), and not before.
* After pseudo-division, the residual angle $z$ satisfies
  $0 \le z < \arctan(2^{1-n}) < 2^{1-n}$, where $n$ is `G_ITERATIONS`. So the
  upper bits of $z$, which are dropped for the multiplication $z \cdot z$, are
  always zero, as claimed in `tan_cordic.vhd`. This holds for any input angle
  in $[0, 1)$.
* The non-restoring division is exact: if $0 \le y \le x < 8$ when the divider is
  loaded, the result is $\lfloor 2^F y/x \rfloor$ (where $F$ is
  `G_FRAC_BITS`), or all ones if $y = x$.

The condition $0 \le y \le x$ depends on the values of sine and cosine, which
induction cannot easily capture. So `tan_cordic_bmc.psl` verifies it with
bounded model checking instead, for one calculation from the reset, with any
angle in $[0, \pi/4)$. It also verifies that the Padé approximation never
saturates (`resize` in `fixed_pkg` saturates by default, which would silently
give a wrong result), and that the rotations never overflow (they wrap). If the angle may be one unit of the last
bit above $\pi/4$, it fails, so the range of the input is tight.

The proofs use `G_ITERATIONS=3` and `G_FRAC_BITS=8` (short traces), and the
default `G_ITERATIONS=6` and `G_FRAC_BITS=24`, each with `G_STEPS=1` and
`G_STEPS=2` (which does not divide `G_ITERATIONS=3`). The default `G_STEPS=4`
is not proven by induction, since with 4 iterations of the division in each clock
cycle it takes too long (about 18 minutes even for 3 and 8). It is verified by
`tan_cordic_bmc.psl`, with the default generics, and by the simulation. The accuracy of the tangent is not verified
formally, only by the simulation.

## Simulation
`make sim` runs the testbench `tb_tan_cordic.vhd` using GHDL (`--std=08`).
The testbench generates angles uniformly distributed in `[0.0, pi/4[`, plus a few
fixed corner cases (zero, an angle just below `pi/4`, and a very small angle), and
randomly stalls both the VALID and READY signals. It stops at the first result that is
outside the tolerance. It:

* Sweeps `G_ITERATIONS` over 2, 4, 6, 8, 16, and 20, `G_FRAC_BITS` over 8, 16,
  20, 24, 28, and 32, and `G_STEPS` over 1, 2, 3, 4, and 8, with 150 angles for each
  of the 180 combinations.
* Verifies accuracy against the tangent calculated with the Taylor series (the `tan`
  of `ieee.math_real` is only accurate to about `2**-28` in GHDL), with a tolerance
  from the error analysis in
  [Accuracy and the number of iterations](ALGORITHM.md#accuracy-and-the-number-of-iterations):
  twice the sum of two units of the last bit and the error of the Padé
  approximation.
* Runs a larger (5000-sample) test at the default configuration
  (`G_ITERATIONS => 6`, `G_FRAC_BITS => 24`, `G_STEPS => 4`).
* Checks operation without stalls, and with a slow consumer or a slow producer (ready
  or valid in only 10% of the clock cycles), with 500 angles each.

With the default configuration, the largest error is about `2**-23.1`, i.e. two units
of the last bit: one from rounding the angle to 24 bits, and one from truncating the
quotient. More iterations do not reduce it.

## Timing
The result is valid `2*ceil(G_ITERATIONS/G_STEPS) + ceil(G_FRAC_BITS/G_STEPS) + 3`
clock cycles after the input is accepted, i.e. 13 clock cycles for the default
configuration. The design meets the 11.5 ns (87.0 MHz) clock constraint in
`tan_cordic.xdc` with a slack of 0.211 ns, for a latency of 150 ns, using 1212 Slice
LUTs, 335 registers, and one DSP48E1.

With `G_FRAC_BITS => 32`, full precision needs 8 iterations: the largest error is
about `2**-31.2`, and against the tangent of the rounded angle it is one unit of the
last bit, `2**-32.0`, the same as with 16 iterations. The result is then valid 15
clock cycles after the input is accepted, and the design meets a clock period of
12.5 ns (80.0 MHz), so the latency is 188 ns. (With 7 iterations the error is slightly
larger, and phases 1 and 3 take as many clock cycles as with 8.) To check this,
change the clock period in `tan_cordic.xdc`, and run
`make vivado VIVADO_ITERATIONS=8 VIVADO_FRAC_BITS=32`.

[Timing](ALGORITHM.md#timing) lists the latency for each value of `G_STEPS`
(`G_STEPS=3` gives the lowest latency for 24 bits, 135 ns, and `G_STEPS=4` for 32
bits), and describes how the critical path was shortened, and how the number of
iterations was reduced from 16 to 6.

## Links
* [https://www.righto.com/2026/09/8087-tangent-cordic.html](https://www.righto.com/2026/09/8087-tangent-cordic.html)
* [https://en.wikipedia.org/wiki/CORDIC](https://en.wikipedia.org/wiki/CORDIC)
