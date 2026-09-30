# Fast divide
This divides two 32-bit unsigned integers using
[Goldschmidt division](https://en.wikipedia.org/wiki/Division_algorithm#Goldschmidt_division),
in VHDL for an FPGA. The quotient is a 64-bit fixed-point number, with 32
integer bits and 32 fraction bits. It takes at most 7 clock cycles (6.74 on
average in the testbench).

The timing constraint in [`fast_divide.xdc`](fast_divide.xdc) is 50 MHz (clock
period 20 ns), which is met with a slack of 3.8 ns. So the design can run at
about 60 MHz (clock period 16.2 ns).

The resource usage is:

* LUT   : 595
* FF    : 175
* Slice : 157
* DSP   :  12

These numbers are from Vivado 2025.1, with `make vivado` (see
[Running](#running)), which implements the design out of context for the part
xc7a200tfbg484-2.

## The algorithm
First the divisor D and the numerator N are both shifted left by the number
of leading zeros in D. This does not change the quotient N/D, and afterwards D
is in the interval [0.5, 1), when regarded as a fixed-point number with the
binary point just above its top bit.

Then each iteration multiplies both N and D by the same factor F = 2 - D:
```
F := 2 - D
N := N * F
D := D * F
```
Again this does not change the quotient. If D = 1 - e, then the new D is
(1 - e)(1 + e) = 1 - e², so the distance to 1 is squared in each iteration,
and D converges quadratically to 1. Since e ≤ 0.5 to begin with, after k
iterations e ≤ 2^(-2^k). When D has reached 1, N is the quotient.

The design does at most 6 iterations, and stops early when D is 1 within the
precision (all ones). N and D are kept with 4 guard bits below the 32 fraction
bits, and the quotient is rounded by adding a small constant before these
guard bits are removed.

Each iteration takes a single clock cycle, and uses two wide multipliers
(68x38 and 36x38 bits).

## Files
| File | Description
| ---- | -----------
| [`fast_divide.vhd`](fast_divide.vhd) | The divider.
| [`tb_fast_divide.vhd`](tb_fast_divide.vhd) | Testbench.
| [`fast_divide.gtkw`](fast_divide.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`fast_divide.xdc`](fast_divide.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (50 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`fast_divide.xpr`](fast_divide.xpr) | Vivado project, for use in the Vivado GUI. It has the same settings as `make vivado`.
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
| `rst_i` | in | Synchronous reset, active high. Clears `m_valid_o`, and abandons a division in progress.
| `s_valid_i`, `s_ready_o` | in, out | Handshake of the input.
| `s_n_i` | in | The numerator, 32 bits, unsigned.
| `s_d_i` | in | The divisor, 32 bits, unsigned.
| `m_valid_o`, `m_ready_i` | out, in | Handshake of the output.
| `m_q_o` | out | The quotient `s_n_i/s_d_i`: bits 63 to 32 are the integer part, and bits 31 to 0 are the fraction.

None of the output signals depend combinatorially on any of the input signals.

`m_valid_o` goes high at most 7 clock cycles after the input is transferred. A
new input is accepted in the clock cycle after the quotient is written to the
output register. A division by zero gives a quotient of all ones (the largest
value), 1 clock cycle after the input is transferred.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench twice, with and without random stalls. This
  requires [GHDL](https://github.com/ghdl/ghdl). It takes about 20 seconds.
* `make debug` runs the testbench with random stalls, and also writes a
  waveform to `fast_divide.ghw`.
  `make show_debug` shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make vivado` synthesizes and implements `fast_divide.vhd`, using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
  for the Artix-7 part xc7a200tfbg484-2. The design is implemented out of
  context, i.e. as a module inside a larger design, so only the paths between
  registers are timed. It fails if the design does not meet the 50 MHz clock
  constraint in `fast_divide.xdc`. At the end it prints the number of cells and the
  slack of the worst path, and the reports are written to `vivado/`. It takes
  about 2 minutes, and expects Vivado in `/opt/Xilinx/2025.1/Vivado` (the variable
  `XILINX_DIR`).
* `make clean` removes the generated files.

## Simulation
The testbench first divides by zero twice, and then divides all pairs of
numerator and divisor from 1 to 100, and compares the result with the exact
quotient, with the fraction rounded to nearest. It prints the average number
of clock cycles per division, which is 7.74 when there are no stalls.

The integer part of the quotient is always correct, but the last bit of the
fraction is not always exact: 1056 of the 10000 divisions report a mismatch
(446 are one too low, 570 are one too high, and 40 are two too high, in units
of 2^-32). These mismatches are reported by the testbench as warnings, but do
not stop the simulation. The summary at the end prints the number of results
that are too low (`low_count`) and too high (`high_count`).

The valid signal of the input and the ready signal of the output are asserted
randomly, with the probabilities given by the generics `G_VALID_PCT` and
`G_READY_PCT` (70% by default). `make sim` also runs the testbench with both at
100%, i.e. without stalls. The results are the same in both cases.
