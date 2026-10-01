# Booth multiplier

This multiplies two signed
([two's complement](https://en.wikipedia.org/wiki/Two%27s_complement)) numbers
using [Booth's algorithm](https://en.wikipedia.org/wiki/Booth%27s_multiplication_algorithm)
with radix 4, in VHDL for an FPGA. Both inputs are `G_DATA_SIZE` bits wide, and
the product is `2*G_DATA_SIZE` bits wide.

The latency is 32 ns for `G_DATA_SIZE=16`, at the 250 MHz clock constraint in
[`booth.xdc`](booth.xdc), and it grows in proportion to `G_DATA_SIZE`, since
each clock cycle handles two bits.

[`booth_csa.vhd`](booth_csa.vhd) is a faster version with the same interface:
It keeps the partial product in carry-save form, so that there is no carry
chain in the iterations, and handles several Booth digits (`G_DIGITS`, default
4) in each clock cycle. With `G_DIGITS=4` and `G_DATA_SIZE=16` the latency is
16 ns at the same clock, and it grows much more slowly with `G_DATA_SIZE`. It
also runs at a higher clock frequency (about 400 MHz), which hardly depends on
`G_DATA_SIZE`. So at the highest clock frequency of each design, the latency
is 2 to 4 times shorter (e.g. 9.7 ns instead of 19.0 ns for 16 bits), for
about 5 times as many LUTs. See
[Carry-save version](ALGORITHM.md#carry-save-version).

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
4. Radix 4 needs half as many clock cycles as radix 2, for the same number of
flip-flops and logic levels, but somewhat more LUTs.

## Files
| File | Description
| ---- | -----------
| [`booth.vhd`](booth.vhd) | The Booth multiplier (radix 4).
| [`booth_radix2.vhd`](booth_radix2.vhd) | The same multiplier with radix 2, for comparison, see [Radix 2 versus radix 4](ALGORITHM.md#radix-2-versus-radix-4).
| [`booth_csa.vhd`](booth_csa.vhd) | The faster multiplier with carry-save addition, see [Carry-save version](ALGORITHM.md#carry-save-version).
| [`tb_booth.vhd`](tb_booth.vhd) | Testbench for all three designs.
| [`booth.gtkw`](booth.gtkw) | GTKWave setup for viewing the waveform from `make debug`.
| [`booth.psl`](booth.psl), [`booth_csa.psl`](booth_csa.psl), [`booth.sby`](booth.sby) | Formal verification of all three designs, see [Formal verification](#formal-verification).
| [`booth.xdc`](booth.xdc), [`vivado.tcl`](vivado.tcl) | Timing constraint (250 MHz) and script for synthesis with Vivado, see `make vivado`.
| [`Makefile`](Makefile) | Runs the simulation, the formal verification, and the synthesis, see [Running](#running).
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm, the comparison of radix 2 and radix 4, and the carry-save version.

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
accepted every 1.5 clock cycles on average.) For `booth_csa.vhd` this is every
`ceil(G_DATA_SIZE/(2*G_DIGITS)) + 2` clock cycles.

## Running
Type `make` to list the supported targets:
* `make sim` runs the testbench (see [below](#simulation)). This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 1.5 minutes.
  `make sim DESIGNS=2` tests only `booth_radix2.vhd`, and e.g.
  `make sim DESIGNS=csa4` tests only `booth_csa.vhd` with `G_DIGITS=4`.
* `make debug` runs a short simulation of `booth.vhd` (20 multiplications),
  and writes a waveform to `booth.ghw`. Use `make show_debug` to view it in
  [GTKWave](https://github.com/gtkwave/gtkwave), with the signals selected in
  `booth.gtkw`.
* `make formal` runs the formal verification (see [below](#formal-verification)).
  This requires [SymbiYosys](https://github.com/YosysHQ/sby), the GHDL plugin
  for Yosys, and the [Boolector](https://github.com/Boolector/boolector) solver.
  It takes about 5 minutes. If it fails, use `make show_prove TASK=prove4`
  or `make show_induct TASK=prove4` to view the counterexample in GTKWave,
  where the task is one of those in `booth.sby`.
* `make synth` estimates the resource usage of all three designs, and prints
  the numbers for the tables in [Resource usage](ALGORITHM.md#resource-usage)
  and [Carry-save version](ALGORITHM.md#carry-save-version). This requires
  [Yosys](https://github.com/YosysHQ/yosys) and the
  [GHDL plugin](https://github.com/ghdl/ghdl-yosys-plugin) for Yosys. It takes
  about 30 seconds.
* `make vivado` synthesizes and implements `booth.vhd` with `G_DATA_SIZE=16`,
  using [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
  for the Artix-7 part xc7a200tfbg484-2. The design is implemented out of
  context, i.e. as a module inside a larger design, so only the paths between
  registers are timed. It fails if the design does not meet the 250 MHz clock
  constraint in `booth.xdc`. At the end it prints the number of cells and the
  slack and logic levels of the worst path, and the reports are written to
  `vivado/booth_16/`. E.g. `make vivado VIVADO_TOP=booth_radix2 VIVADO_SIZE=32`
  selects another design and size. It takes about 1.5 minutes, and expects
  Vivado in `/opt/Xilinx/2025.1/Vivado` (the variable `XILINX_DIR`).
* `make clean` removes the generated files.

The CI (`.github/workflows/booth.yml`) runs `make sim`, `make formal`, and
`make synth` on every pull request, and every push to master, that changes this
directory.

## Simulation
`make sim` runs the testbench `tb_booth.vhd` for `booth.vhd`,
`booth_radix2.vhd`, and `booth_csa.vhd` (with `G_DIGITS` from 1 to 4). The
testbench randomly stalls both the VALID and READY signals, and for each
design it:

* Tests all pairs of inputs for `G_DATA_SIZE` from 1 to 7.
* Tests 5000 pairs of inputs for `G_DATA_SIZE` of 16, 17, and 32: first all
  pairs of the values most negative, -1, 0, 1, and largest positive, and then
  random pairs. Random inputs almost never hit the most negative value at these
  sizes, which is the case that P needs its two extra bits for.
* Verifies the throughput when there are no stalls, for `G_DATA_SIZE` of 8
  and 9: one product every `ceil(G_DATA_SIZE/2)` clock cycles for radix 4,
  every `G_DATA_SIZE` clock cycles for radix 2, and every
  `ceil(G_DATA_SIZE/(2*G_DIGITS)) + 2` clock cycles for `booth_csa.vhd`.
* Tests a slow consumer, which is ready in only 10% of the clock cycles.

It prints "All tests passed" at the end, and stops with an error at the first
wrong product.

## Formal verification
The formal verification (`booth.psl`, `booth_csa.psl`, `booth.sby`) proves
for all three designs, for every sequence of inputs and stalls, including
resets:
* Every product is correct, and they come out in order: none is lost, and none
  is duplicated.
* The product stays valid and unchanged until it is taken.
* If the consumer is ready, the product is valid one calculation after the
  input was accepted: `ceil(G_DATA_SIZE/2)` clock cycles for radix 4,
  `G_DATA_SIZE` clock cycles for radix 2, and
  `ceil(G_DATA_SIZE/(2*G_DIGITS)) + 2` clock cycles for `booth_csa.vhd`.
* If the consumer is always ready, a new input is accepted after every
  calculation, i.e. the throughput (for `G_DATA_SIZE >= 3` in radix 4, and
  `G_DATA_SIZE >= 2` in radix 2).

`booth.psl` models the multiplier at its ports: a queue of the input pairs
whose product has not been taken yet. The properties are proven with
k-induction, so they hold in every clock cycle, not just for a bounded number
of them. This relies on the invariant of Booth's algorithm (see
[Theory of operation](ALGORITHM.md#theory-of-operation)), which relates the
working register to the pair in the queue. `booth_csa.psl` has the same
checker at the ports, and the same invariant for the carry-save form, see
[Carry-save version](ALGORITHM.md#carry-save-version). Cover statements show that the
interesting cases are reached, e.g. the product of the most negative numbers,
and a calculation that finishes while the previous product is still waiting.

The solver is given the multiplication `a*b` directly, which is only practical
for small sizes. So the proofs use `G_DATA_SIZE=8` for all designs, and
`G_DATA_SIZE=7` for an odd size in radix 4 and in `booth_csa.vhd`, where Q is
sign-extended. `booth_csa.vhd` is proven with `G_DIGITS` of 1, 2, and 3, and
with blocks of 3 bits in the final adder, so that there are several blocks. With
`G_DATA_SIZE=16` they do not finish within 10 minutes. The design is the same
for every size, and the simulation tests the larger sizes.
