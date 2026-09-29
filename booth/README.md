# Booth multiplier

This multiplies two signed
([two's complement](https://en.wikipedia.org/wiki/Two%27s_complement)) numbers
using [Booth's algorithm](https://en.wikipedia.org/wiki/Booth%27s_multiplication_algorithm)
with radix 4, in VHDL for an FPGA. Both inputs are `G_DATA_SIZE` bits wide, and
the product is `2*G_DATA_SIZE` bits wide.

The calculation takes `ceil(G_DATA_SIZE/2)` clock cycles, i.e. one clock cycle
per two bits.

## The algorithm
The product is calculated by adding shifted multiples of the multiplicand M,
like long multiplication by hand. Booth's algorithm first recodes the
multiplier Q, so that a run of ones needs only a subtraction at its start and
an addition at its end. With radix 4, each iteration handles two bits of Q, and
the recoded digit is one of {-2, -1, 0, 1, 2}. So each iteration only adds 0,
±M, or ±2M to the partial product, and these are all obtained from M by
shifting and inverting, with a single adder.

[ALGORITHM.md](ALGORITHM.md) explains the algorithm in detail: the Booth
recoding, how `booth.vhd` implements it, and a comparison of radix 2 and radix
4. Radix 4 needs half as many clock cycles as radix 2, for about the same
hardware.

## Files
| File | Description
| ---- | -----------
| [`booth.vhd`](booth.vhd) | The Booth multiplier (radix 4).
| [`booth_radix2.vhd`](booth_radix2.vhd) | The same multiplier with radix 2, for comparison, see [Radix 2 versus radix 4](ALGORITHM.md#radix-2-versus-radix-4).
| [`tb_booth.vhd`](tb_booth.vhd) | Testbench for both designs.
| [`Makefile`](Makefile) | Runs the simulation and the synthesis, see [Running](#running).
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm, and the comparison of radix 2 and radix 4.

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

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench (see [below](#simulation)). This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 10 seconds.
  `make sim RADIX=2` tests only `booth_radix2.vhd`.
* `make debug` runs a short simulation of `booth.vhd` (20 multiplications),
  and writes a waveform to `booth.ghw`. Use `make show_debug` to view it in
  [GTKWave](https://github.com/gtkwave/gtkwave).
* `make synth` estimates the resource usage of both designs, and prints the
  numbers for the table in [Resource usage](ALGORITHM.md#resource-usage). This requires
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
