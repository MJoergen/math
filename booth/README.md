# Booth multiplier

This multiplies two signed (two's complement) numbers using Booth's algorithm (radix 2).
Both inputs are `G_DATA_SIZE` bits wide, and the product is `2*G_DATA_SIZE` bits wide.

The calculation takes `G_DATA_SIZE` clock cycles, i.e. one clock cycle per bit.

## Interface
Both input and output use an AXI-style VALID/READY handshake:

* The two inputs `s_a_i` and `s_b_i` share the handshake signals `s_valid_i` and `s_ready_o`.
* The product `m_res_o` uses the handshake signals `m_valid_o` and `m_ready_i`.

None of the output signals depend combinatorially on any of the input signals.

The product is written to a separate output register, so a new calculation can begin while
the previous product is waiting to be consumed. In the last clock cycle of a calculation a
new pair of inputs is accepted, provided the output register is empty. So when there are no
stalls, a new pair of inputs is accepted every `G_DATA_SIZE` clock cycles.

## Theory of operation
Let M be the multiplicand and Q be the multiplier. A working register is formed by
concatenating P (the partial product, initially zero), Q, and an extra bit Q(-1)
(initially zero):

`prod = P & Q & Q(-1)`

In each of `G_DATA_SIZE` iterations, the two least significant bits Q(0) and Q(-1) are
examined:

| Q(0) Q(-1) | Operation   |
| ---------- | ----------- |
| 00         | No change   |
| 01         | P := P + M  |
| 10         | P := P - M  |
| 11         | No change   |

Then the entire register is shifted one bit to the right (arithmetic shift).
After `G_DATA_SIZE` iterations the product is found in `P & Q`.

The idea is that a run of ones in the multiplier, e.g. `0011110`, has the value
`0100000 - 0000010`. So instead of one addition for each bit set, there is only a
subtraction at the start of the run and an addition at the end of the run.

P is one bit wider than M, so that the operation P - M does not overflow when M is the
most negative number, i.e. -2^(G\_DATA\_SIZE-1).

## Resource usage
Estimated with Yosys (`synth_xilinx`):

| `G_DATA_SIZE` | LUT | FF  | CARRY4 |
| ------------- | --- | --- | ------ |
|  8            |  52 |  48 |  7     |
| 16            |  96 |  89 | 12     |
| 32            | 175 | 170 | 20     |

## Simulation
The script `sim.sh` runs the testbench `tb_booth.vhd` using GHDL. The testbench
randomly stalls both the VALID and READY signals, and it:

* Tests all pairs of inputs for `G_DATA_SIZE` from 1 to 7.
* Tests 5000 random pairs of inputs for `G_DATA_SIZE` of 16 and 32.
* Verifies the throughput of one product every `G_DATA_SIZE` clock cycles, when there are
  no stalls.

## Links
* [https://en.wikipedia.org/wiki/Booth%27s_multiplication_algorithm](https://en.wikipedia.org/wiki/Booth%27s_multiplication_algorithm)
