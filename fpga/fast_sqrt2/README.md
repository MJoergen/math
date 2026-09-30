# Square root, version 2
This calculates the square root of a C64 floating point number, using an
iterative method with multipliers, in VHDL for an FPGA. It has the same
interface as [`fast_sqrt`](../fast_sqrt), but takes 5 to 9 clock cycles
(7.1 on average in the testbench) instead of 33. The number of clock cycles
depends on how many iterations are needed.

When `C_ROM_SIZE=6` and `C_GUARDS=4` (see [`fast_sqrt2.vhd`](fast_sqrt2.vhd))
we have the following statistics:

* Cycles = 8.1
* low\_count = 275
* high\_count = 189
* Period = 13.2 ns
* DSP = 8
* LUT = 394
* FF = 213
* Slice = 129

Cycles, `low_count`, and `high_count` are printed by the testbench, see
[Simulation](#simulation). Cycles includes the overhead of the testbench.

The other numbers are from Vivado 2025.1, with `make vivado` (see
[Running](#running)), which implements the design out of context for the part
xc7a200tfbg484-2, and meets the timing constraint in
[`fast_sqrt2.xdc`](fast_sqrt2.xdc), a clock period of 13.2 ns (75.8 MHz), with a
slack of 0.086 ns. The timing is sensitive to placement: with a clock period
of 12.5 to 13.0 ns, the timing is missed by up to 0.6 ns.

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
The exponent is handled as in `fast_sqrt`: It is halved, and the mantissa is
placed one bit differently depending on whether the exponent is even or odd.
The square root s of the mantissa is calculated with the form of
[Goldschmidt's algorithm](https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Goldschmidt%E2%80%99s_algorithm)
that uses fused multiply-add operations. It begins with
```
y0 := approximation of 1/sqrt(s)
x0 := s*y0
h0 := y0/2
```
and iterates
```
r  := 0.5 - x*h
x  := x + x*r
h  := h + h*r
```
until r is sufficiently close to 0. Then x is sqrt(s), and h is
0.5/sqrt(s).

The initial approximation comes from a small table (ROM) indexed by the top
`C_ROM_SIZE` bits of the mantissa. The calculation uses `C_GUARDS` extra bits
below the 32 bits of the mantissa, and the result is rounded to nearest.

Each iteration takes two clock cycles, one for r and one for x and h, using
the two multiply-add units in [`dsp.vhd`](dsp.vhd). The iterations stop when
the top half of the bits of r are zero.

## Files
| File | Description
| ---- | -----------
| [`fast_sqrt2.vhd`](fast_sqrt2.vhd) | The square root.
| [`dsp.vhd`](dsp.vhd) | A combinatorial multiply-add, `a*b+c`, intended for the DSP blocks.
| [`tb_fast_sqrt2.vhd`](tb_fast_sqrt2.vhd) | Testbench.
| [`fast_sqrt2.gtkw`](fast_sqrt2.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`fast_sqrt2.xdc`](fast_sqrt2.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (75.8 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`fast_sqrt2.xpr`](fast_sqrt2.xpr) | Vivado project, for use in the Vivado GUI. It has the same settings as `make vivado`.
| [`Makefile`](Makefile) | Runs the simulation and the synthesis, see [Running](#running).

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
  [GHDL](https://github.com/ghdl/ghdl). It takes about 20 seconds.
* `make debug` does the same, and also writes a waveform to `fast_sqrt2.ghw`.
  `make show_debug` shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make vivado` synthesizes and implements `fast_sqrt2.vhd`, using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
  for the Artix-7 part xc7a200tfbg484-2. The design is implemented out of
  context, i.e. as a module inside a larger design, so only the paths between
  registers are timed. It fails if the design does not meet the 75.8 MHz clock
  constraint in `fast_sqrt2.xdc`. At the end it prints the number of cells and the
  slack of the worst path, and the reports are written to `vivado/`. It takes
  about 2 minutes, and expects Vivado in `/opt/Xilinx/2025.1/Vivado` (the variable
  `XILINX_DIR`).
* `make clean` removes the generated files.

## Simulation
The testbench calculates the square root of 0, 1, 2, 3, 4, 0.5, and -1 (which
gives an error), and of 15938 values from 0.031 to 8. It compares each result
with the exact square root, rounded to nearest, and prints the average number
of clock cycles per calculation (8.1, including the overhead of the
testbench).

The last bit of the mantissa is not always exact: 464 of the results report a
mismatch. These mismatches are reported by the testbench, but do not stop the
simulation. The summary at the end prints the number of results that are too
low (`low_count`, 275) and too high (`high_count`, 189).
