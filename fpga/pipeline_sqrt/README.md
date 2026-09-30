# Pipelined square root

This calculates the square root of a number with 21 bits of accuracy, i.e. more than six
decimal digits.

Input: The range of values is [1, 4[, and the value is encoded as fixed point 2.20.
       The integer part (upper two bits) must be nonzero.

Output: The range of values is [1, 2[, and the fractional part is encoded as fixed point
        0.22 (the integer part is constant 1).

It is a 2-stage pipeline: It accepts a new input in every clock cycle, and the result
is available 2 clock cycles after the input. The input and the output use an AXI-style
VALID/READY handshake, see [Interface](#interface).

## FPGA resources
This implementation uses two BRAMs and one DSP, and a small amount of extra logic.
The exact numbers for each value of G_EXTRA_BITS are listed under
[Test results](#test-results).

It can run at a clock speed of 125 MHz (clock period 8 ns). The numbers are from
Vivado 2025.1, with `make vivado` (see [Running](#running)), which implements the design
out of context for the part xc7a200tfbg484-2, and meets the timing constraint in
[`pipeline_sqrt.xdc`](pipeline_sqrt.xdc) with a slack of at least 1.7 ns.

The clock period cannot be reduced much: With a clock period of 7.5 ns or less, Vivado
synthesis implements some or all of the ROMs in LUTs (and F7 and F8 muxes) instead of
Block RAM, e.g. 383 LUTs and 1 BRAM at 7.5 ns, and 807 LUTs and 0 BRAM at 6 ns (both
with G_EXTRA_BITS = 2).

## Theory of operation
The calculation performed is x = sqrt(y), where y is the real input number and x is the
real output number.
The input number y is required to be in the range [1, 4[.

1. First the input number y is decomposed into two parts:
`y = a + b*eps`
where a is in the range [1, 4[, b is in the range [0, 1[, and eps = 2^(-9).
In this way, the value a can be
represented in fixed point 2.9 and the number b in fixed point 0.11

2. Second the number a is used as index into two lookup tables (BRAMs)
The first gives `f(a) = sqrt(a)-1` represented as fixed point 0.18
The second gives `g(a) = (2/sqrt(a))-1` represented as fixed point 0.18

3. The formula for calculating x = sqrt(y) is based on a Taylor
expansion to first order in eps:

In general we have `f(a+b*eps) == f(a) + f'(a)*b*eps`
where "==" means approximately equal to.

Here we use f(y) = sqrt(y), and we thus get
`sqrt(y) == sqrt(a) + (2/sqrt(a))*b*(eps/4)`

4. The above scheme only gives 18 bits of accuracy, and this limitation
is mainly from the first lookup table for f(a). So, to improve accuracy, the
function f(a) is calculated to 22 bits accuracy, and only the lower 18 bits are stored in
BRAM. The upper 4 bits are calculated combinatorially. This is controlled by the generic
G_EXTRA_BITS.

## Files
| File | Description
| ---- | -----------
| [`pipeline_sqrt.vhd`](pipeline_sqrt.vhd) | The square root.
| [`tb_pipeline_sqrt.vhd`](tb_pipeline_sqrt.vhd) | Testbench.
| [`pipeline_sqrt.gtkw`](pipeline_sqrt.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`pipeline_sqrt.xdc`](pipeline_sqrt.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (125 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`pipeline_sqrt.xpr`](pipeline_sqrt.xpr) | Vivado project, for use in the Vivado GUI. It has the same settings as `make vivado`, with G_EXTRA_BITS = 2.
| [`Makefile`](Makefile) | Runs the simulation and the synthesis, see [Running](#running).

## Interface
The generic `G_EXTRA_BITS` is the number of upper bits of f(a) that are calculated
combinatorially, from 0 to 4, see [Theory of operation](#theory-of-operation).

Both the input and the output use an
[AXI](https://en.wikipedia.org/wiki/Advanced_eXtensible_Interface)-style
VALID/READY handshake: a value is transferred in a clock cycle where both valid
and ready are high. The sender keeps valid high and the value unchanged until
then.

| Port | Direction | Description
| ---- | --------- | -----------
| `clk_i` | in | Clock.
| `rst_i` | in | Synchronous reset, active high. Clears `m_valid_o`, and discards the values in the pipeline.
| `s_valid_i`, `s_ready_o` | in, out | Handshake of the input.
| `s_data_i` | in | The input y, fixed point 2.20 in the range [1, 4[.
| `m_valid_o`, `m_ready_i` | out, in | Handshake of the output.
| `m_data_o` | out | The fractional part of x = sqrt(y), fixed point 0.22. The integer part is constant 1.

None of the output signals depend combinatorially on any of the input signals.

`m_valid_o` goes high 2 clock cycles after the input is transferred. When
`m_ready_i` is high, a new input is accepted in every clock cycle. When the output
register is full and `m_ready_i` is low, the whole pipeline stalls. Since
`s_ready_o` is a register, it only goes low one clock cycle later. An input that is
accepted in the meantime is stored in a skid buffer, and enters the pipeline when the
stall is over.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench five times, for G_EXTRA_BITS from 0 to 4, and then once
  more with random stalls. This requires [GHDL](https://github.com/ghdl/ghdl). Each run
  takes about 3 to 4 minutes. E.g. `make sim EXTRA_BITS=2` runs only G_EXTRA_BITS = 2
  (and the run with stalls).
* `make debug` runs the testbench for 2000 inputs with G_EXTRA_BITS = 2 and random
  stalls, and writes a waveform to `pipeline_sqrt.ghw`. `make show_debug` shows it in
  [GTKWave](https://github.com/gtkwave/gtkwave).
* `make vivado` synthesizes and implements `pipeline_sqrt.vhd` with G_EXTRA_BITS = 2,
  using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
  for the Artix-7 part xc7a200tfbg484-2. The design is implemented out of context, i.e.
  as a module inside a larger design, so only the paths between registers are timed. It
  fails if the design does not meet the 125 MHz clock constraint in `pipeline_sqrt.xdc`.
  At the end it prints the number of cells and the slack of the worst path, and the
  reports are written to `vivado/pipeline_sqrt_2/`. E.g. `make vivado VIVADO_EXTRA_BITS=4`
  selects another value of G_EXTRA_BITS. It takes about 2 minutes, and expects Vivado in
  `/opt/Xilinx/2025.1/Vivado` (the variable `XILINX_DIR`).
* `make clean` removes the generated files.

## Simulation
The testbench cycles through all 3*2^20 valid values of the input, from 0x100000 (1.0)
to 0x3FFFFF (just below 4.0), one in each clock cycle, and compares each output with the
exact square root, rounded down. It prints the input and the output whenever the error is
larger than any previous error. These are the tables under [Test results](#test-results).
The testbench stops if the error is larger than 0x20, or if there is not a result in
every clock cycle.

The last run of `make sim` has random stalls: The valid signal of the input and the
ready signal of the output are asserted randomly, with the probabilities given by the
generics `G_VALID_PCT` and `G_READY_PCT` (70%). The inputs are taken in a scrambled
order (the generic `G_STRIDE`), so that consecutive inputs differ a lot, and a lost or
duplicated value would give a large error.

## Test results

To verify the implementation in simulation, there is a testbench that cycles through all
3*2^20 valid values of the input, and compares with the expected output. It prints out whenever
the error is larger than any previous error.

It takes approx 3 minutes to run the entire simulation for each value of G_EXTRA_BITS.

`make sim` runs the simulation five times for different values of G_EXTRA_BITS, see
[Running](#running).

The main results are below. The synthesis reports are from Vivado 2025.1 with a clock
period of 8 ns, from `make vivado VIVADO_EXTRA_BITS=n`, see [FPGA resources](#fpga-resources).
About 29 LUTs and 25 registers are for the handshake (the skid buffer, the valid bits,
and the clock enable of the pipeline); the rest grows with G_EXTRA_BITS.

### G_EXTRA_BITS = 0

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  0x100401 |  0x000800  |  0x000801 |
|  0x100800 |  0x000FF0  |  0x000FFE |
|  0x100801 |  0x000FF1  |  0x001000 |
|  0x1039E4 |  0x007350  |  0x007360 |
|  0x10AA35 |  0x0150E2  |  0x0150F3 |

Maximal error is 0x000011, i.e. approx 2^4, so the accuracy
is 22-4 = 18 bits.

Analysis of the final row:
* data_in  = 0x10AA35
* sqrt_low = 0x014C9
* inv_sqrt = 0x3D64E
* data_lsb = 0x235
* b        = 0x235
* f        = 0x00532400000
* g        = 0x7D64E
* abc      = 0x005438BFA26
* data_out = 0x0150E2

Synthesis report
* LUT   = 29
* REG   = 25
* BRAM  = 2
* DSP   = 1


### G_EXTRA_BITS = 1

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  0x100401 |  0x000800  |  0x000801 |
|  0x100800 |  0x000FF8  |  0x000FFE |
|  0x100801 |  0x000FF9  |  0x001000 |
|  0x1039E4 |  0x007358  |  0x007360 |
|  0x1080DF |  0x00FFB6  |  0x00FFBF |

Maximal error is 0x000009, i.e. approx 2^3, so the accuracy
is 22-3 = 19 bits.

Analysis of the final row:
* data_in   = 0x1080DF
* sqrt_low  = 0x01FC0
* sqrt_high = 0x0
* inv_sqrt  = 0x3DFC6
* data_lsb  = 0x0DF
* b         = 0x0DF
* f         = 0x003F8000000
* g         = 0x7DFC6
* abc       = 0x003FEDBED7A
* data_out  = 0x00FFB6

Synthesis report
* LUT   = 31
* REG   = 27
* BRAM  = 2
* DSP   = 1


### G_EXTRA_BITS = 2

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  0x100401 |  0x000800  |  0x000801 |
|  0x100800 |  0x000FFC  |  0x000FFE |
|  0x100801 |  0x000FFD  |  0x001000 |
|  0x1039E4 |  0x00735C  |  0x007360 |
|  0x1080DF |  0x00FFBA  |  0x00FFBF |

Maximal error is 0x000005, i.e. approx 2^2, so the accuracy
is 22-2 = 20 bits.

Analysis of the final row:
* data_in   = 0x1080DF
* sqrt_low  = 0x03F81
* sqrt_high = 0x0
* inv_sqrt  = 0x3DFC6
* data_lsb  = 0x0DF
* b         = 0x0DF
* f         = 0x003F8100000
* g         = 0x7DFC6
* abc       = 0x003FEEBED7A
* data_out  = 0x00FFBA

Synthesis report
* LUT   = 34
* REG   = 29
* BRAM  = 2
* DSP   = 1


### G_EXTRA_BITS = 3

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  0x100401 |  0x000800  |  0x000801 |
|  0x1039E4 |  0x00735E  |  0x007360 |
|  0x105064 |  0x009FFD  |  0x00A000 |

Maximal error is 0x000003, i.e. approx 2^1, so the accuracy
is 22-1 = 21 bits.

Analysis of the final row:
* data_in   = 0x105064
* sqrt_low  = 0x04F9C
* sqrt_high = 0x0
* inv_sqrt  = 0x3EB51
* data_lsb  = 0x064
* b         = 0x064
* f         = 0x0027CE00000
* g         = 0x7EB51
* abc       = 0x0027FF7EBA4
* data_out  = 0x009FFD

Synthesis report
* LUT   = 40
* REG   = 31
* BRAM  = 2
* DSP   = 1


### G_EXTRA_BITS = 4

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  0x100401 |  0x000800  |  0x000801 |
|  0x1039E4 |  0x00735E  |  0x007360 |

Maximal error is 0x000002, i.e. approx 2^1, so the accuracy
is 22-1 = 21 bits.

Analysis of the final row:
* data_in   = 0x1039E4
* sqrt_low  = 0x06F9E
* sqrt_high = 0x0
* inv_sqrt  = 0x3F129
* data_lsb  = 0x1E4
* b         = 0x1E4
* f         = 0x001BE780000
* g         = 0x7F129
* abc       = 0x001CD7BF184
* data_out  = 0x00735E

Synthesis report
* LUT   = 47
* REG   = 33
* F7MUX = 1
* BRAM  = 2
* DSP   = 1


