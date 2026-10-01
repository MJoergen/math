# Sine and cosine
This calculates both the sine and the cosine of a
[C64 floating point number](../README.md#c64-floating-point-format), using the
[CORDIC](https://en.wikipedia.org/wiki/CORDIC) algorithm, in VHDL for an FPGA.

It can run at a clock speed of 75.5 MHz (clock period 13.25 ns), and the
latency is 133 ns (10 clock cycles), with the default of 4 CORDIC iterations
in each clock cycle (the generic `G_STEPS`).

The resource usage is:

* LUT   : 1741
* FF    :  246
* Slice :  451
* DSP   :    4

These numbers are from Vivado 2025.1, with `make vivado` (see
[Running](#running)), which implements the design out of context for the part
xc7a200tfbg484-2, and meets the timing constraint in
[`c64_sincos.xdc`](c64_sincos.xdc) with a slack of 0.456 ns. The timing is
sensitive to placement: a clock period of 12.9 ns (a latency of 129 ns) is
also met, but 13.0 ns is not. The latency for other values of `G_STEPS` is
listed in [Timing and resources](ALGORITHM.md#timing-and-resources).

The largest absolute error of the sine and the cosine is 2^(-31.4) for angles
in the range [0, pi/4], and 2^(-31.2) in the range [-2pi, 2pi]. This is the
accuracy of the 33 CORDIC iterations, see [The algorithm](#the-algorithm). For
larger angles the error grows, see [Accuracy](ALGORITHM.md#accuracy).

## The algorithm
The calculation has five steps:
1. Reduce the angle modulo 2pi, and convert it to fixed point (i.e. apply the
   exponent). For this, the angle is first multiplied by 2/pi.
2. Determine the octant, and reduce the angle to [0, pi/4].
3. Apply the CORDIC algorithm.
4. Construct the sine and cosine from the result of step 3, using the octant.
5. Normalize the results, i.e. calculate the exponents.

Steps 1 and 2 take one clock cycle, and so do steps 4 and 5.

CORDIC calculates the sine and cosine by rotating the vector (x, y), starting
at (K, 0), by the angles ±arctan(2^-i) for i = 0, 1, 2, and so on. Each
rotation only needs shifts and additions, and the direction is chosen so that
the remaining angle approaches zero. The constant K compensates for the
lengthening of the vector in each rotation. In the end, x is the cosine and y
is the sine. The design does 33 iterations: The first one always rotates by
+arctan(1), so it is done together with step 2, and the other 32 are done
`G_STEPS` at a time, in 32/`G_STEPS` clock cycles. The error
after the last iteration is at most the angle of that iteration, arctan(2^-32),
so each extra iteration halves the error, until the rounding errors of the
guard bits (see below) take over. With 29 iterations the error is 2^(-28), and
with 32 it is 2^(-30.8). See also
[An Introduction to the CORDIC Algorithm](https://www.allaboutcircuits.com/technical-articles/an-introduction-to-the-cordic-algorithm/).

The fixed point numbers have 7 guard bits below the 32 bits of the mantissa,
to reduce the accumulation of rounding errors, see
[`c64_sincos_pkg.vhd`](c64_sincos_pkg.vhd).

[ALGORITHM.md](ALGORITHM.md) explains the algorithm in detail: the range
reduction, the CORDIC iterations, how the sine and cosine are reconstructed
from the octant, what limits the accuracy (also for tiny and for large
angles), and the number of iterations versus the accuracy.

## Files
| File | Description
| ---- | -----------
| [`c64_sincos.vhd`](c64_sincos.vhd) | The sine and cosine.
| [`c64_sincos_pkg.vhd`](c64_sincos_pkg.vhd) | The fixed point type used in the calculation, and conversion functions for it.
| [`tb_c64_sincos.vhd`](tb_c64_sincos.vhd) | Testbench.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm.
| [`c64_sincos.gtkw`](c64_sincos.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`c64_sincos.xdc`](c64_sincos.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (75.5 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`c64_sincos.xpr`](c64_sincos.xpr) | Vivado project, for use in the Vivado GUI. It has the same settings as `make vivado`.
| [`cordic.xlsx`](cordic.xlsx) | Spreadsheet that goes through the CORDIC iterations step by step.
| [`Makefile`](Makefile) | Runs the simulation and the synthesis, see [Running](#running).

## Interface
The generic `G_STEPS` is the number of CORDIC iterations in each clock cycle
(default 4). 32 must be divisible by it, i.e. it is 1, 2, 4, 8, 16, or 32. See
[Timing and resources](ALGORITHM.md#timing-and-resources) for the latency and
resource usage of each.

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
| `s_exp_i`, `s_mant_i` | in | The angle in radians, a C64 floating point number.
| `m_valid_o`, `m_ready_i` | out, in | Handshake of the output.
| `m_sin_exp_o`, `m_sin_mant_o` | out | The sine, a C64 floating point number.
| `m_cos_exp_o`, `m_cos_mant_o` | out | The cosine, a C64 floating point number.

None of the output signals depend combinatorially on any of the input signals.

`m_valid_o` goes high 32/`G_STEPS` + 2 clock cycles after the input is
transferred, i.e. 10 clock cycles for `G_STEPS=4`. A new input is accepted in
the clock cycle after the result is written to the output register, so when
there are no stalls, a new input is accepted every 32/`G_STEPS` + 3 clock
cycles. The generic `G_DEBUG` enables reports of the intermediate values in
the simulation.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench with random stalls for each value of
  `G_STEPS`, and without stalls for `G_STEPS=4`. This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about a second. E.g.
  `make sim STEPS=4` runs the testbench with random stalls only for
  `G_STEPS=4`.
* `make debug` runs the testbench with random stalls, and also writes a
  waveform to `c64_sincos.ghw`.
  `make show_debug` shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make vivado` synthesizes and implements `c64_sincos.vhd` with `G_STEPS=4`, using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
  for the Artix-7 part xc7a200tfbg484-2. The design is implemented out of
  context, i.e. as a module inside a larger design, so only the paths between
  registers are timed. It fails if the design does not meet the 75.5 MHz clock
  constraint in `c64_sincos.xdc`. At the end it prints the number of cells and the
  slack of the worst path, and the reports are written to `vivado/c64_sincos_4/`.
  E.g. `make vivado VIVADO_STEPS=2` selects another value of `G_STEPS` (which
  needs another clock constraint, see
  [Timing and resources](ALGORITHM.md#timing-and-resources)). It takes about
  2.5 minutes, and expects Vivado in `/opt/Xilinx/2025.1/Vivado` (the variable
  `XILINX_DIR`).
* `make clean` removes the generated files.

## Simulation
The testbench calculates the sine and cosine of 121 angles from 0 to pi/4, and
checks that the absolute error is less than 2^(-31). It prints the average
number of clock cycles per calculation (32/`G_STEPS` + 3, e.g. 11 for
`G_STEPS=4`), and the largest absolute error of the sine and of the cosine,
and the angles where they occur. The errors are 2^(-31.4) for both, for all
values of `G_STEPS`.

The expected values are calculated with the Taylor series, and not with `sin`
and `cos` from `ieee.math_real`: GHDL calculates those with CORDIC too (with
28 iterations), so their error is about 2^(-28), much larger than the error
that is being measured.

The valid signal of the input and the ready signal of the output are asserted
randomly, with the probabilities given by the generics `G_VALID_PCT` and
`G_READY_PCT` (70% by default). `make sim` also runs the testbench with both at
100%, i.e. without stalls, for `G_STEPS=4`. The results are the same in all
cases. Since the iterations are the same, only grouped differently into clock
cycles, the results are also bit-identical to those of the earlier version
with one iteration in each clock cycle (checked for 3000 random angles with
all exponents).

GHDL prints a few warnings about metavalues in the first clock cycles, before
the first calculation is started.
