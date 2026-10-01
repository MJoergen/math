# Square root, version 2
This calculates the square root of a
[C64 floating point number](../README.md#c64-floating-point-format), using an
iterative method with multipliers, in VHDL for an FPGA. It has the same
interface as [`c64_sqrt`](../c64_sqrt), but has a latency of 40 to 119 ns
(94 ns on average in the testbench) instead of 139 ns, at a lower clock
frequency (75.8 MHz). The latency depends on how many iterations are needed.

When `C_ROM_SIZE=6` and `C_GUARDS=4` (see [`c64_sqrt2.vhd`](c64_sqrt2.vhd))
we have the following statistics:

* Latency = 94 ns (average)
* low\_count = 275
* high\_count = 189
* Period = 13.2 ns
* DSP = 8
* LUT = 528
* FF = 234
* Slice = 158

The latency, `low_count`, and `high_count` are from the testbench, see
[Simulation](#simulation). The testbench prints the average number of clock
cycles per calculation when there are no stalls, 8.1. This is the latency
plus the clock cycle where the input is accepted, so the latency is 7.1 clock
cycles of 13.2 ns.

The other numbers are from Vivado 2025.1, with `make vivado` (see
[Running](#running)), which implements the design out of context for the part
xc7a200tfbg484-2, and meets the timing constraint in
[`c64_sqrt2.xdc`](c64_sqrt2.xdc), a clock period of 13.2 ns (75.8 MHz), with a
slack of 0.338 ns. The timing is sensitive to placement: with a clock period
of 12.5 to 13.0 ns, the timing was missed by up to 0.6 ns.

## The algorithm
The exponent is handled as in `c64_sqrt`: It is halved, and the mantissa is
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

[ALGORITHM.md](ALGORITHM.md) explains the algorithm in detail: why it
converges, how the initial approximation is chosen, where the rounding errors
come from, and how the table size and the number of guard bits trade latency
and accuracy against size.

## Files
| File | Description
| ---- | -----------
| [`c64_sqrt2.vhd`](c64_sqrt2.vhd) | The square root.
| [`dsp.vhd`](dsp.vhd) | A combinatorial multiply-add, `a*b+c`, intended for the DSP blocks.
| [`tb_c64_sqrt2.vhd`](tb_c64_sqrt2.vhd) | Testbench.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm.
| [`c64_sqrt2.gtkw`](c64_sqrt2.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`c64_sqrt2.xdc`](c64_sqrt2.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (75.8 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`c64_sqrt2.xpr`](c64_sqrt2.xpr) | Vivado project, for use in the Vivado GUI. It has the same settings as `make vivado`.
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
| `s_exp_i`, `s_mant_i` | in | The input, a C64 floating point number.
| `m_valid_o`, `m_ready_i` | out, in | Handshake of the output.
| `m_exp_o`, `m_mant_o` | out | The square root, a C64 floating point number.
| `m_error_o` | out | High when the input is negative. Then the result is zero.

None of the output signals depend combinatorially on any of the input signals.

`m_valid_o` goes high 3 to 9 clock cycles after the input is transferred (1
clock cycle when the input is zero or negative, since the result is then zero).
A new input is accepted in the clock cycle after the result is written to the
output register.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench twice, with and without random stalls. This
  requires [GHDL](https://github.com/ghdl/ghdl). It takes about 40 seconds.
* `make debug` runs the testbench with random stalls, and also writes a
  waveform to `c64_sqrt2.ghw`.
  `make show_debug` shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make vivado` synthesizes and implements `c64_sqrt2.vhd`, using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
  for the Artix-7 part xc7a200tfbg484-2. The design is implemented out of
  context, i.e. as a module inside a larger design, so only the paths between
  registers are timed. It fails if the design does not meet the 75.8 MHz clock
  constraint in `c64_sqrt2.xdc`. At the end it prints the number of cells and the
  slack of the worst path, and the reports are written to `vivado/`. It takes
  about 2 minutes, and expects Vivado in `/opt/Xilinx/2025.1/Vivado` (the variable
  `XILINX_DIR`).
* `make clean` removes the generated files.

## Simulation
The testbench calculates the square root of 0, 1, 2, 3, 4, 0.5, and -1 (which
gives an error), and of 15938 values from 0.031 to 8. It compares each result
with the exact square root, rounded to nearest, and prints the average number
of clock cycles per calculation (8.1).

The last bit of the mantissa is not always exact: 464 of the results report a
mismatch. These mismatches are reported by the testbench as warnings, but do
not stop the simulation. The summary at the end prints the number of results
that are too low (`low_count`, 275) and too high (`high_count`, 189).

The valid signal of the input and the ready signal of the output are asserted
randomly, with the probabilities given by the generics `G_VALID_PCT` and
`G_READY_PCT` (70% by default). `make sim` also runs the testbench with both at
100%, i.e. without stalls. The results are the same in both cases.
