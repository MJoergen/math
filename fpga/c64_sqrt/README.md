# Square root
This calculates the square root of a
[C64 floating point number](../README.md#c64-floating-point-format), using a
simple bit-shifting algorithm, in VHDL for an FPGA.

It can run at a clock speed of 94.3 MHz (clock period 10.6 ns), and the
latency is 95 ns (9 clock cycles), with the default of 4 iterations in each
clock cycle (the generic `G_STEPS`).

The resource usage is:

* LUT   : 236
* FF    : 129
* Slice :  86

These numbers are from Vivado 2025.1, with `make vivado` (see
[Running](#running)), which implements the design out of context for the part
xc7a200tfbg484-2, and meets the timing constraint in
[`c64_sqrt.xdc`](c64_sqrt.xdc) with a slack of 0.113 ns. This is the highest
clock frequency found: with a clock period of 10.4 ns, the timing is not met.
The latency for other values of `G_STEPS` is listed in
[Timing](ALGORITHM.md#timing).

[`c64_sqrt2`](../c64_sqrt2) is another version, which uses multipliers, and
whose latency depends on the input.

## The algorithm
The exponent is halved. The mantissa is placed one bit differently depending
on whether the exponent is even or odd, so that the power of two that is
halved is always even.

The square root of the mantissa is calculated with the
[digit-by-digit method](https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2)),
which finds one bit of the result in each iteration, like long division by
hand, using only shifts, additions, and subtractions. It is used in its
non-restoring form, where each iteration is a single addition or subtraction.
The first bit is always one, and the remaining 32 bits are calculated with
`G_STEPS` iterations in each clock cycle. The last bit is an extra bit, which
is used for rounding the result to nearest.

[ALGORITHM.md](ALGORITHM.md) explains the algorithm in detail: how the
registers hold the root and the remainder as integers, so that each bit only
needs one addition or subtraction, the non-restoring form, why the result is
always correctly rounded, and the timing and resource usage for each value of
`G_STEPS`.

## Files
| File | Description
| ---- | -----------
| [`c64_sqrt.vhd`](c64_sqrt.vhd) | The square root.
| [`tb_c64_sqrt.vhd`](tb_c64_sqrt.vhd) | Testbench.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm.
| [`c64_sqrt.gtkw`](c64_sqrt.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`c64_sqrt.xdc`](c64_sqrt.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (94.3 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`c64_sqrt.xpr`](c64_sqrt.xpr) | Vivado project, for use in the Vivado GUI. It has the same settings as `make vivado`.
| [`Makefile`](Makefile) | Runs the simulation and the synthesis, see [Running](#running).

## Interface
The generic `G_STEPS` is the number of iterations in each clock cycle (default
4). 32 must be divisible by it, i.e. it is 1, 2, 4, 8, 16, or 32. See
[Timing](ALGORITHM.md#timing) for the latency and resource usage of each.

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

`m_valid_o` goes high 32/`G_STEPS` + 1 clock cycles after the input is
transferred, i.e. 9 clock cycles for `G_STEPS=4` (1 clock cycle when the input
is zero or negative, since the result is then zero). The result is written to a
separate output register, and in the same clock cycle a new input is accepted,
provided the output register is empty. So when there are no stalls, a new input
is accepted every 32/`G_STEPS` + 1 clock cycles.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench with random stalls for each value of
  `G_STEPS`, and without stalls for `G_STEPS=4`. This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 1 minute. E.g.
  `make sim STEPS=4` runs the testbench with random stalls only for
  `G_STEPS=4`.
* `make debug` runs the testbench with random stalls, and also writes a
  waveform to `c64_sqrt.ghw`.
  `make show_debug` shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make vivado` synthesizes and implements `c64_sqrt.vhd` with `G_STEPS=4`, using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
  for the Artix-7 part xc7a200tfbg484-2. The design is implemented out of
  context, i.e. as a module inside a larger design, so only the paths between
  registers are timed. It fails if the design does not meet the 94.3 MHz clock
  constraint in `c64_sqrt.xdc`. At the end it prints the number of cells and the
  slack of the worst path, and the reports are written to `vivado/c64_sqrt_4/`.
  E.g. `make vivado VIVADO_STEPS=2` selects another value of `G_STEPS` (which
  needs another clock constraint, see [Timing](ALGORITHM.md#timing)). It takes
  about 2 minutes, and expects Vivado in `/opt/Xilinx/2025.1/Vivado` (the
  variable `XILINX_DIR`).
* `make clean` removes the generated files.

## Simulation
The testbench calculates the square root of 0, 1, 2, 3, 4, 0.5, and -1 (which
gives an error), of 1 - 2^(-32) and 1 + 2^(-31) (the two inputs where the last
iteration decides the rounding, see
[The last iteration](ALGORITHM.md#the-last-iteration)), and of 15938 values
from 0.031 to 8. It checks that each result is the exact square root, rounded
to nearest, and stops at the first mismatch. There are no mismatches. The
check is done exactly with integers, since the square root in double
precision is not always precise enough to decide the rounding.

The valid signal of the input and the ready signal of the output are asserted
randomly, with the probabilities given by the generics `G_VALID_PCT` and
`G_READY_PCT` (70% by default). `make sim` runs the testbench for each value
of `G_STEPS`, and also with both probabilities at 100%, i.e. without stalls,
for `G_STEPS=4`. At the end the testbench prints the average number of clock
cycles per calculation, which is 32/`G_STEPS` + 1, e.g. 9 for `G_STEPS=4`
(slightly less on average, since zero and negative inputs take 1 clock cycle,
and slightly more with stalls for large `G_STEPS`).
