# Sine and cosine
This calculates both the sine and the cosine of a
[C64 floating point number](../README.md#c64-floating-point-format), using the
[CORDIC](https://en.wikipedia.org/wiki/CORDIC) algorithm, in VHDL for an FPGA.

It can safely run at a clock speed of 156 MHz (clock period 6.4 ns), and the
latency is 237 ns.

The resource usage is:

* LUT   : 1305
* FF    :  385
* Slice :  327
* DSP   :    4

These numbers are from Vivado 2025.1, with `make vivado` (see
[Running](#running)), which implements the design out of context for the part
xc7a200tfbg484-2, and meets the timing constraint in
[`c64_sincos.xdc`](c64_sincos.xdc) with a slack of 0.228 ns.

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
5. Normalize the results, i.e. calculate the exponents. This takes one clock
   cycle after the last CORDIC iteration.

CORDIC calculates the sine and cosine by rotating the vector (x, y), starting
at (K, 0), by the angles ±arctan(2^-i) for i = 0, 1, 2, and so on. Each
rotation only needs shifts and additions, and the direction is chosen so that
the remaining angle approaches zero. The constant K compensates for the
lengthening of the vector in each rotation. In the end, x is the cosine and y
is the sine. The design does 33 iterations, one per clock cycle. The error
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
| [`c64_sincos.xdc`](c64_sincos.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (156 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`c64_sincos.xpr`](c64_sincos.xpr) | Vivado project, for use in the Vivado GUI. It has the same settings as `make vivado`.
| [`cordic.xlsx`](cordic.xlsx) | Spreadsheet that goes through the CORDIC iterations step by step.
| [`Makefile`](Makefile) | Runs the simulation and the synthesis, see [Running](#running).

## Interface
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

`m_valid_o` goes high 37 clock cycles after the input is transferred. A new
input is accepted in the clock cycle after the result is written to the output
register, so when there are no stalls, a new input is accepted every 38 clock
cycles. The generic `G_DEBUG` enables reports of the intermediate values in
the simulation.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench twice, with and without random stalls. This
  requires [GHDL](https://github.com/ghdl/ghdl). It takes about a second.
* `make debug` runs the testbench with random stalls, and also writes a
  waveform to `c64_sincos.ghw`.
  `make show_debug` shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make vivado` synthesizes and implements `c64_sincos.vhd`, using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
  for the Artix-7 part xc7a200tfbg484-2. The design is implemented out of
  context, i.e. as a module inside a larger design, so only the paths between
  registers are timed. It fails if the design does not meet the 156 MHz clock
  constraint in `c64_sincos.xdc`. At the end it prints the number of cells and the
  slack of the worst path, and the reports are written to `vivado/`. It takes
  about 2.5 minutes, and expects Vivado in `/opt/Xilinx/2025.1/Vivado` (the variable
  `XILINX_DIR`).
* `make clean` removes the generated files.

## Simulation
The testbench calculates the sine and cosine of 121 angles from 0 to pi/4, and
checks that the absolute error is less than 2^(-31). It prints the average
number of clock cycles per calculation (38), and the largest absolute error of
the sine and of the cosine, and the angles where they occur. The errors are
2^(-31.4) for both.

The expected values are calculated with the Taylor series, and not with `sin`
and `cos` from `ieee.math_real`: GHDL calculates those with CORDIC too (with
28 iterations), so their error is about 2^(-28), much larger than the error
that is being measured.

The valid signal of the input and the ready signal of the output are asserted
randomly, with the probabilities given by the generics `G_VALID_PCT` and
`G_READY_PCT` (70% by default). `make sim` also runs the testbench with both at
100%, i.e. without stalls. The results are the same in both cases.

GHDL prints a few warnings about metavalues in the first clock cycles, before
the first calculation is started.
