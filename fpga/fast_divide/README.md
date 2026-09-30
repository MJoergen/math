# Fast divide
This divides two 32-bit unsigned integers using
[Goldschmidt division](https://en.wikipedia.org/wiki/Division_algorithm#Goldschmidt_division),
in VHDL for an FPGA. The quotient is a 64-bit fixed-point number, with 32
integer bits and 32 fraction bits. It takes at most 7 clock cycles (6.74 on
average in the testbench).

The timing constraint in [`fast_divide.xdc`](fast_divide.xdc) is 50 MHz (clock
period 20 ns), which is met with a slack of 3.5 ns. So the design can run at
about 60 MHz (clock period 16.5 ns).

The resource usage is:

* LUT   : 568
* FF    : 175
* Slice : 192
* DSP   :  12

These numbers are from Vivado 2025.1, implementing the project
[`fast_divide.xpr`](fast_divide.xpr) (part xc7a200tfbg484-2, default
strategies).

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
| [`fast_divide.xdc`](fast_divide.xdc) | Timing constraint (50 MHz).
| [`fast_divide.xpr`](fast_divide.xpr) | Vivado project for synthesis.
| [`Makefile`](Makefile) | Runs the simulation, see [Running](#running).

## Interface
| Port | Direction | Description
| ---- | --------- | -----------
| `clk_i` | in | Clock.
| `n_i` | in | The numerator, 32 bits, unsigned.
| `d_i` | in | The divisor, 32 bits, unsigned.
| `start_over_i` | in | Starts a new division of `n_i` by `d_i`, also if a division is in progress.
| `q_o` | out | The quotient `n_i/d_i`: bits 63 to 32 are the integer part, and bits 31 to 0 are the fraction.
| `busy_o` | out | High while a division is in progress. `q_o` is valid when it is low.

`busy_o` goes high in the clock cycle after `start_over_i`. A division by zero
is ignored, i.e. `start_over_i` has no effect when `d_i` is zero. There is no
reset.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench. This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 10 seconds.
* `make debug` does the same, and also writes a waveform to `fast_divide.ghw`.
  `make show_debug` shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make clean` removes the generated files.

## Simulation
The testbench divides all pairs of numerator and divisor from 1 to 100, and
compares the result with the exact quotient, with the fraction rounded to
nearest. It prints the average number of clock cycles per division, which is
7.74 including the overhead of the testbench.

The integer part of the quotient is always correct, but the last bit of the
fraction is not always exact: 1056 of the 10000 divisions report a mismatch
(446 are one too low, 570 are one too high, and 40 are two too high, in units
of 2^-32). These mismatches are reported by the testbench, but do not stop the
simulation. The summary at the end prints the number of results that are too
low (`low_count`) and too high (`high_count`).
