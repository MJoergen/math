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
| [`booth.psl`](booth.psl), [`booth.sby`](booth.sby) | Formal verification of both designs, see [Formal verification](#formal-verification).
| [`Makefile`](Makefile) | Runs the simulation, the formal verification, and the synthesis, see [Running](#running).
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
* `make formal` runs the formal verification (see [below](#formal-verification)).
  This requires [SymbiYosys](https://github.com/YosysHQ/sby), the GHDL plugin
  for Yosys, and the [Boolector](https://github.com/Boolector/boolector) solver.
  It takes about 1.5 minutes. If it fails, use `make show_prove TASK=prove4`
  or `make show_induct TASK=prove4` to view the counterexample in GTKWave,
  where the task is one of those in `booth.sby`.
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
* Tests 5000 pairs of inputs for `G_DATA_SIZE` of 16, 17, and 32: first all
  pairs of the values most negative, -1, 0, 1, and largest positive, and then
  random pairs. Random inputs almost never hit the most negative value at these
  sizes, which is the case that P needs its two extra bits for.
* Verifies the throughput when there are no stalls, for `G_DATA_SIZE` of 8
  and 9: one product every `ceil(G_DATA_SIZE/2)` clock cycles for radix 4, and
  every `G_DATA_SIZE` clock cycles for radix 2.
* Tests a slow consumer, which is ready in only 10% of the clock cycles.

It prints "All tests passed" at the end, and stops with an error at the first
wrong product.

## Formal verification
The formal verification (`booth.psl`, `booth.sby`) proves for both designs,
for every sequence of inputs and stalls, including resets:
* Every product is correct, and they come out in order: none is lost, and none
  is duplicated.
* The product stays valid and unchanged until it is taken.
* If the consumer is ready, the product is valid one calculation after the
  input was accepted: `ceil(G_DATA_SIZE/2)` clock cycles for radix 4, and
  `G_DATA_SIZE` clock cycles for radix 2.
* If the consumer is always ready, a new input is accepted after every
  calculation, i.e. the throughput (for `G_DATA_SIZE >= 3` in radix 4, and
  `G_DATA_SIZE >= 2` in radix 2).

`booth.psl` models the multiplier at its ports: a queue of the input pairs
whose product has not been taken yet. The properties are proven with
k-induction, so they hold in every clock cycle, not just for a bounded number
of them. This relies on the invariant of Booth's algorithm (see
[Theory of operation](ALGORITHM.md#theory-of-operation)), which relates the
working register to the pair in the queue. Cover statements show that the
interesting cases are reached, e.g. the product of the most negative numbers,
and a calculation that finishes while the previous product is still waiting.

The solver is given the multiplication `a*b` directly, which is only practical
for small sizes. So the proofs use `G_DATA_SIZE=8` for both designs, and
`G_DATA_SIZE=7` for an odd size in radix 4, where Q is sign-extended. With
`G_DATA_SIZE=16` they do not finish within 10 minutes. The design is the same
for every size, and the simulation tests the larger sizes.
