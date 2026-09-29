# Booth multiplier

This multiplies two signed
([two's complement](https://en.wikipedia.org/wiki/Two%27s_complement)) numbers
using [Booth's algorithm](https://en.wikipedia.org/wiki/Booth%27s_multiplication_algorithm)
with radix 4, in VHDL for an FPGA. Both inputs are `G_DATA_SIZE` bits wide, and
the product is `2*G_DATA_SIZE` bits wide.

The calculation takes `ceil(G_DATA_SIZE/2)` clock cycles, i.e. one clock cycle
per two bits.

## Files
| File | Description
| ---- | -----------
| [`booth.vhd`](booth.vhd) | The Booth multiplier (radix 4).
| [`booth_radix2.vhd`](booth_radix2.vhd) | The same multiplier with radix 2, for comparison, see [Radix 2 versus radix 4](#radix-2-versus-radix-4).
| [`tb_booth.vhd`](tb_booth.vhd) | Testbench for both designs.
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
| `s_a_i` | in | The multiplicand M, `G_DATA_SIZE` bits, signed.
| `s_b_i` | in | The multiplier Q, `G_DATA_SIZE` bits, signed.
| `m_valid_o`, `m_ready_i` | out, in | Handshake of the output.
| `m_res_o` | out | The product `s_a_i*s_b_i`, `2*G_DATA_SIZE` bits, signed.

None of the output signals depend combinatorially on any of the input signals.

The product is written to a separate output register, so a new calculation can
begin while the previous product is waiting to be consumed. In the last clock
cycle of a calculation a new pair of inputs is accepted, provided the output
register is empty. So when there are no stalls, a new pair of inputs is
accepted every `ceil(G_DATA_SIZE/2)` clock cycles. (For `G_DATA_SIZE` of 1 or
2 the calculation takes only one clock cycle, and a new pair of inputs is
accepted every 1.5 clock cycles on average.)

## Theory of operation
Let M be the multiplicand (`s_a_i`) and Q be the multiplier (`s_b_i`). If
`G_DATA_SIZE` is odd, then Q is sign-extended by one bit, so that it has an even
number of bits. A working register is formed by concatenating P (the partial
product, initially zero), Q, and an extra bit Q(-1) (initially zero):

`prod = P & Q & Q(-1)`

In each of `ceil(G_DATA_SIZE/2)` iterations, the three least significant bits
of the working register, Q(1), Q(0), and Q(-1), are examined:

| Q(1) Q(0) Q(-1) | Operation   |
| --------------- | ----------- |
| 000             | No change   |
| 001             | P := P + M  |
| 010             | P := P + M  |
| 011             | P := P + 2M |
| 100             | P := P - 2M |
| 101             | P := P - M  |
| 110             | P := P - M  |
| 111             | No change   |

Then the entire register is shifted two bits to the right (arithmetic shift).
After `ceil(G_DATA_SIZE/2)` iterations the product is the low `2*G_DATA_SIZE`
bits of `P & Q`. The upper bits are just sign extension.

The operation is simply M times the recoded digit `Q(-1) + Q(0) - 2*Q(1)`. This
recoding comes from the original (radix 2) Booth algorithm, where a run of ones
in the multiplier, e.g. `0011110`, has the value `0100000 - 0000010`. So instead
of one addition for each bit set, there is only a subtraction at the start of
the run and an addition at the end of the run. Radix 4 simply combines two such
radix 2 steps into a single step.

Since 2M is just M shifted one bit to the left, only a single adder is needed.
The operand (0, M, or 2M) is selected first, and subtraction is performed by
inverting the operand and setting the carry input of the adder.

P is two bits wider than M, so that the operation P - 2M does not overflow when
M is the most negative number, i.e. `-2^(G_DATA_SIZE-1)`.

## Radix 2 versus radix 4
The original (radix 2) Booth algorithm examines two bits, Q(0) and Q(-1), and
shifts one bit per iteration. The only operations are 0, +M, and -M. To compare
the two options, [`booth_radix2.vhd`](booth_radix2.vhd) implements radix 2 with
the same interface, the same output register, and the same single-adder
structure. Only the parts that depend on the radix are different.

### Resource usage
Estimated with [Yosys](https://github.com/YosysHQ/yosys) 0.56 (`synth_xilinx`,
for Xilinx 7-series FPGAs), by running `make synth`:

| `G_DATA_SIZE` | Clock cycles | LUT       | FF        | CARRY4  | Logic levels |
| ------------- | ------------ | --------- | --------- | ------- | ------------ |
|  8            |  8 /  4      |  49 /  52 |  48 /  47 |  4 /  4 |  6 /  6      |
| 16            | 16 /  8      |  77 /  74 |  89 /  88 |  7 /  6 |  7 /  7      |
| 32            | 32 / 16      | 172 / 175 | 170 / 169 | 11 / 11 | 12 / 12      |
| 64            | 64 / 32      | 330 / 331 | 331 / 330 | 19 / 19 | 19 / 19      |

Each entry is radix 2 / radix 4. LUT, FF, and CARRY4 are the numbers of cells
in the whole design. "Logic levels" is the largest number of LUT and CARRY4
cells on any path between two registers, as Vivado counts logic levels. They
are the CARRY4 cells of the adder's carry chain, plus two or three LUTs.

### Performance
Radix 4 needs half as many clock cycles for each product. This halves the
latency and doubles the throughput, for the same clock frequency.

### Utilization
The two options use essentially the same amount of hardware:

* FF: The partial product P is one bit wider in radix 4, but the iteration
  counter is one bit narrower. For odd `G_DATA_SIZE`, the multiplier Q is also
  one bit wider. The net difference is at most one or two flip-flops.
* Adder: Both use a single adder, of width `G_DATA_SIZE+1` and `G_DATA_SIZE+2`
  respectively. The number of CARRY4 cells is almost the same. The small
  difference is due to rounding, and to the smaller iteration counter in radix
  4.
* LUT: Radix 4 must additionally choose between M and 2M. But 2M is just M
  shifted one bit to the left, so this is just a 2-to-1 multiplexer on each bit,
  and no extra adder is needed. The LUT counts differ by at most 6%, in either
  direction.

### Timing
The critical path is the same in both cases: From the registers, through the
operand selection logic, through the carry chain of the adder, and back into
the working register.

* The carry chain is one bit longer in radix 4.
* The operand selection logic for each bit is a function of P(i), M(i), Q(0),
  and Q(-1) in radix 2 (four inputs), and of P(i), M(i), M(i-1), Q(1), Q(0),
  and Q(-1) in radix 4 (six inputs). On an FPGA with 6-input LUTs, both fit
  into a single LUT. In the table above, both designs have the same number of
  logic levels for every `G_DATA_SIZE`.

On an FPGA with 4-input LUTs (or in an ASIC), the extra multiplexer in radix 4
does add a logic level in front of the adder, which slightly lowers the maximum
clock frequency.

### Trade-off
There is hardly any trade-off: Radix 4 gives twice the performance for roughly
the same hardware, and on an FPGA with 6-input LUTs the same number of logic
levels. So the time for each product (the number of clock cycles times the
clock period) is close to half that of radix 2.

The reason radix 4 is so cheap is the Booth recoding. The recoded digits are in
the range {-2, -1, 0, 1, 2}, and all multiples of M in this range are obtained
by shifting and inverting. A plain (non-Booth) radix 4 multiplier would need
the digit 3, and hence the multiple 3M, which requires an extra adder.

The real trade-off appears when going beyond radix 4. Radix 8 Booth has digits
in the range {-4, ..., 4}, and so needs the "hard" multiple 3M. This requires an
extra adder (or an extra clock cycle) to precompute 3M, an extra register to
store it, and a wider multiplexer, which no longer fits in a single 6-input LUT.
So radix 8 gives 33% fewer clock cycles than radix 4, at the cost of
significantly more hardware and a longer critical path. Radix 4 is therefore
the sweet spot for this kind of sequential multiplier.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench (see [below](#simulation)). This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 10 seconds.
  `make sim RADIX=2` tests only `booth_radix2.vhd`.
* `make debug` runs a short simulation of `booth.vhd` (20 multiplications),
  and writes a waveform to `booth.ghw`. Use `make show_debug` to view it in
  [GTKWave](https://github.com/gtkwave/gtkwave).
* `make synth` estimates the resource usage of both designs, and prints the
  numbers for the table in [Resource usage](#resource-usage). This requires
  [Yosys](https://github.com/YosysHQ/yosys) and the
  [GHDL plugin](https://github.com/ghdl/ghdl-yosys-plugin) for Yosys. It takes
  about 20 seconds.
* `make clean` removes the generated files.

## Simulation
`make sim` runs the testbench `tb_booth.vhd` for both `booth.vhd` and
`booth_radix2.vhd`. The testbench randomly stalls both the VALID and READY
signals, and for each design it:

* Tests all pairs of inputs for `G_DATA_SIZE` from 1 to 7.
* Tests 5000 random pairs of inputs for `G_DATA_SIZE` of 16, 17, and 32.
* Verifies the throughput when there are no stalls, for `G_DATA_SIZE` of 8
  and 9: one product every `ceil(G_DATA_SIZE/2)` clock cycles for radix 4, and
  every `G_DATA_SIZE` clock cycles for radix 2.
* Tests a slow consumer, which is ready in only 10% of the clock cycles.

It prints "All tests passed" at the end, and stops with an error at the first
wrong product.
