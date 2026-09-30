# Sine and cosine
This calculates both the sine and the cosine of a C64 floating point number,
using the [CORDIC](https://en.wikipedia.org/wiki/CORDIC) algorithm, in VHDL
for an FPGA. It takes 32 clock cycles.

It can safely run at a clock speed of 156 MHz (clock period 6.4 ns). The total
latency is thus 205 ns.

The resource usage is:

* LUT   : 1086
* FF    :  384
* Slice :  315
* DSP   :    4

These numbers are from Vivado 2025.1, implementing the project
[`fast_sincos.xpr`](fast_sincos.xpr) (part xc7a200tfbg484-2, default
strategies), which meets the timing constraint in
[`fast_sincos.xdc`](fast_sincos.xdc) with a slack of 0.218 ns.

The absolute deviation for angles in the range [0, pi/4] is 2^(-32).
The absolute deviation for angles in the range [-2pi, 2pi] is 2^(-26).

## The number format
The input and the outputs use the 5-byte floating point format of the C64
BASIC, see [Floating point arithmetic](https://www.c64-wiki.com/wiki/Floating_point_arithmetic):
An exponent byte and a 32-bit mantissa. The value is 0.1mmm... (binary) times
2^(exp-128), where bit 31 of the mantissa holds the sign instead of the
leading one. An exponent of zero means the value 0.0.

| Value | Exp  | Mantissa
| ----- | ---- | --------
|   0.0 | 0x00 | any
|   0.5 | 0x80 | 0x00000000
|   1.0 | 0x81 | 0x00000000
|  -1.0 | 0x81 | 0x80000000

## The algorithm
The calculation has five steps:
1. Reduce the angle modulo 2pi, and convert it to fixed point (i.e. apply the
   exponent). For this, the angle is first multiplied by 2/pi.
2. Determine the octant, and reduce the angle to [0, pi/4].
3. Apply the CORDIC algorithm.
4. Construct the sine and cosine from the result of step 3, using the octant.
5. Normalize the results, i.e. calculate the exponents.

CORDIC calculates the sine and cosine by rotating the vector (x, y), starting
at (K, 0), by the angles ±arctan(2^-i) for i = 0, 1, 2, and so on. Each
rotation only needs shifts and additions, and the direction is chosen so that
the remaining angle approaches zero. The constant K compensates for the
lengthening of the vector in each rotation. In the end, x is the cosine and y
is the sine. The design does 29 iterations, one per clock cycle. See also
[An Introduction to the CORDIC Algorithm](https://www.allaboutcircuits.com/technical-articles/an-introduction-to-the-cordic-algorithm/).

The fixed point numbers have 7 guard bits below the 32 bits of the mantissa,
to reduce the accumulation of rounding errors, see
[`fast_sincos_pkg.vhd`](fast_sincos_pkg.vhd).

## Files
| File | Description
| ---- | -----------
| [`fast_sincos.vhd`](fast_sincos.vhd) | The sine and cosine.
| [`fast_sincos_pkg.vhd`](fast_sincos_pkg.vhd) | The fixed point type used in the calculation, and conversion functions for it.
| [`tb_fast_sincos.vhd`](tb_fast_sincos.vhd) | Testbench.
| [`fast_sincos.gtkw`](fast_sincos.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`fast_sincos.xdc`](fast_sincos.xdc) | Timing constraint (156 MHz).
| [`fast_sincos.xpr`](fast_sincos.xpr) | Vivado project for synthesis.
| [`cordic.xlsx`](cordic.xlsx) | Spreadsheet that goes through the CORDIC iterations step by step.
| [`Makefile`](Makefile) | Runs the simulation, see [Running](#running).

## Interface
| Port | Direction | Description
| ---- | --------- | -----------
| `clk_i` | in | Clock.
| `start_i` | in | Starts a new calculation, also if a calculation is in progress.
| `arg_exp_i`, `arg_mant_i` | in | The angle in radians, a C64 floating point number.
| `ready_o` | out | High when the result is ready.
| `sin_exp_o`, `sin_mant_o` | out | The sine, a C64 floating point number.
| `cos_exp_o`, `cos_mant_o` | out | The cosine, a C64 floating point number.

`ready_o` goes low in the clock cycle after `start_i`, and high again when the
result is ready. There is no reset. The generic `G_DEBUG` enables reports of
the intermediate values in the simulation.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench. This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about a second.
* `make debug` does the same, and also writes a waveform to `fast_sincos.ghw`.
  `make show_debug` shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make clean` removes the generated files.

## Simulation
The testbench calculates the sine and cosine of 121 angles from 0 to pi/4. It
prints the average number of clock cycles per calculation (36, including the
overhead of the testbench), and the largest absolute error of the sine and of
the cosine, and the angles where they occur. The errors are about 2^(-32). The
testbench does not check the results against a limit.

GHDL prints a few warnings about metavalues in the first clock cycles, before
the first calculation is started.
