# Square root
This calculates the square root of a C64 floating point number, using a simple
bit-shifting algorithm, in VHDL for an FPGA. It takes 33 clock cycles.

It can safely run at a clock speed of 244 MHz (clock period 4.1 ns). The total
latency is thus 135 ns.

The resource usage is:

* LUT   : 167
* FF    : 111
* Slice :  76

These numbers are from Vivado 2025.1, implementing the project
[`fast_sqrt.xpr`](fast_sqrt.xpr) (part xc7a200tfbg484-2, default strategies),
which meets the timing constraint in [`fast_sqrt.xdc`](fast_sqrt.xdc) with a
slack of 0.200 ns.

[`fast_sqrt2`](../fast_sqrt2) is a faster version, which uses multipliers.

## The number format
The input and the output use the 5-byte floating point format of the C64
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
The exponent is halved. The mantissa is placed one bit differently depending
on whether the exponent is even or odd, so that the power of two that is
halved is always even.

The square root of the mantissa is calculated with the
[digit-by-digit method](https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2)),
which finds one bit of the result in each clock cycle, like long division by
hand, using only shifts, subtractions, and comparisons. It calculates one extra
bit, which is used for rounding the result to nearest.

## Files
| File | Description
| ---- | -----------
| [`fast_sqrt.vhd`](fast_sqrt.vhd) | The square root.
| [`tb_fast_sqrt.vhd`](tb_fast_sqrt.vhd) | Testbench.
| [`fast_sqrt.gtkw`](fast_sqrt.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`fast_sqrt.xdc`](fast_sqrt.xdc) | Timing constraint (244 MHz).
| [`fast_sqrt.xpr`](fast_sqrt.xpr) | Vivado project for synthesis.
| [`Makefile`](Makefile) | Runs the simulation, see [Running](#running).

## Interface
| Port | Direction | Description
| ---- | --------- | -----------
| `clk_i` | in | Clock.
| `start_i` | in | Starts a new calculation, also if a calculation is in progress.
| `exp_i`, `mant_i` | in | The input, a C64 floating point number.
| `ready_o` | out | High when the result is ready.
| `error_o` | out | High when the input is negative. Then no calculation is started.
| `exp_o`, `mant_o` | out | The square root, a C64 floating point number.

`ready_o` goes low in the clock cycle after `start_i`, and high again when the
result is ready. When the input is zero, the result is zero, and `ready_o`
stays high. There is no reset.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench. This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 5 seconds.
* `make debug` does the same, and also writes a waveform to `fast_sqrt.ghw`.
  `make show_debug` shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make clean` removes the generated files.

## Simulation
The testbench calculates the square root of 0, 1, 2, 3, 4, 0.5, and -1 (which
gives an error), and of 15938 values from 0.031 to 8. It compares each result
with the exact square root, rounded to nearest, and stops at the first
mismatch. There are no mismatches. It also prints the average number of clock
cycles per calculation, which is 35 including the overhead of the testbench.
