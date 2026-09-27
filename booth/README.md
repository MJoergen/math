# Booth multiplier

This multiplies two signed (two's complement) numbers using Booth's algorithm (radix 4).
Both inputs are `G_DATA_SIZE` bits wide, and the product is `2*G_DATA_SIZE` bits wide.

The calculation takes `ceil(G_DATA_SIZE/2)` clock cycles, i.e. one clock cycle per two bits.

## Interface
Both input and output use an AXI-style VALID/READY handshake:

* The two inputs `s_a_i` and `s_b_i` share the handshake signals `s_valid_i` and `s_ready_o`.
* The product `m_res_o` uses the handshake signals `m_valid_o` and `m_ready_i`.

None of the output signals depend combinatorially on any of the input signals.

The product is written to a separate output register, so a new calculation can begin while
the previous product is waiting to be consumed. In the last clock cycle of a calculation a
new pair of inputs is accepted, provided the output register is empty. So when there are no
stalls, a new pair of inputs is accepted every `ceil(G_DATA_SIZE/2)` clock cycles (for
`G_DATA_SIZE` >= 3).

## Theory of operation
Let M be the multiplicand and Q be the multiplier. If `G_DATA_SIZE` is odd, then Q is
sign-extended by one bit, so that it has an even number of bits. A working register is
formed by concatenating P (the partial product, initially zero), Q, and an extra bit Q(-1)
(initially zero):

`prod = P & Q & Q(-1)`

In each of `ceil(G_DATA_SIZE/2)` iterations, the three least significant bits Q(1), Q(0),
and Q(-1) are examined:

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
After `ceil(G_DATA_SIZE/2)` iterations the product is found in `P & Q`.

The operation is simply M times the recoded digit `Q(-1) + Q(0) - 2*Q(1)`. This recoding
comes from the original (radix 2) Booth algorithm, where a run of ones in the multiplier,
e.g. `0011110`, has the value `0100000 - 0000010`. So instead of one addition for each bit
set, there is only a subtraction at the start of the run and an addition at the end of the
run. Radix 4 simply combines two such radix 2 steps into a single step.

Since 2M is just M shifted one bit to the left, only a single adder is needed. The operand
(0, M, or 2M) is selected first, and subtraction is performed by inverting the operand and
setting the carry input of the adder.

P is two bits wider than M, so that the operation P - 2M does not overflow when M is the
most negative number, i.e. -2^(G\_DATA\_SIZE-1).

## Resource usage
Estimated with Yosys (`synth_xilinx`):

| `G_DATA_SIZE` | LUT | FF  | CARRY4 |
| ------------- | --- | --- | ------ |
|  8            |  52 |  47 |  4     |
| 16            |  74 |  88 |  6     |
| 32            | 175 | 169 | 11     |

## Radix 2 versus radix 4
The original (radix 2) Booth algorithm examines two bits, Q(0) and Q(-1), and shifts one
bit per iteration. The only operations are 0, +M, and -M. To compare the two options, a
radix 2 version was made with the same interface, the same output register, and the same
single-adder structure. It is not part of this directory.

The results are estimated with Yosys (`synth_xilinx`). "LUT levels" and "CARRY4" are the
number of LUTs and carry chain cells on the longest register-to-register path.

| `G_DATA_SIZE` | Clock cycles | LUT       | FF        | CARRY4  | LUT levels |
| ------------- | ------------ | --------- | --------- | ------- | ---------- |
|  8            |  8 /  4      |  41 /  52 |  48 /  47 |  4 /  4 | 2 / 3      |
| 16            | 16 /  8      |  77 /  74 |  89 /  88 |  7 /  6 | 2 / 2      |
| 32            | 32 / 16      | 140 / 175 | 170 / 169 | 11 / 11 | 2 / 3      |
| 64            | 64 / 32      | 330 / 331 | 331 / 330 | 19 / 19 | 2 / 2      |

Each entry is radix 2 / radix 4.

### Performance
Radix 4 needs half as many clock cycles for each product. This halves the latency and doubles
the throughput, for the same clock frequency.

### Utilization
The two options use essentially the same amount of hardware:

* FF: The partial product P is one bit wider in radix 4, but the iteration counter is one
  bit narrower. For odd `G_DATA_SIZE`, the multiplier Q is also one bit wider. The net
  difference is at most one or two flip-flops.
* Adder: Both use a single adder, of width `G_DATA_SIZE+1` and `G_DATA_SIZE+2`
  respectively. The number of CARRY4 cells is almost the same. The small difference is
  due to rounding, and to the smaller iteration counter in radix 4.
* LUT: Radix 4 must additionally choose between M and 2M. But 2M is just M shifted one bit
  to the left, so this is just a 2-to-1 multiplexer on each bit, and no extra adder is
  needed. The LUT counts vary by up to 25% in either direction, without a consistent
  winner, so the difference is mostly due to how the synthesis tool maps the logic.

### Timing
The critical path is the same in both cases: From the registers, through the operand
selection logic, through the carry chain of the adder, and back into the working register.

* The carry chain has the same length (one extra bit in radix 4).
* The operand selection logic for each bit is a function of P(i), M(i), Q(0), and Q(-1) in
  radix 2 (four inputs), and of P(i), M(i), M(i-1), Q(1), Q(0), and Q(-1) in radix 4 (six
  inputs). On an FPGA with 6-input LUTs, both fit into a single LUT. In practice the
  synthesis tool sometimes adds an extra LUT level in radix 4, as seen in the table above.

On an FPGA with 4-input LUTs (or in an ASIC), the extra multiplexer in radix 4 does add a
logic level in front of the adder, which slightly lowers the maximum clock frequency.

### Trade-off
There is hardly any trade-off: Radix 4 gives twice the performance for roughly the same
hardware, at the cost of at most one extra LUT level on the critical path. Since that extra
LUT level is much less than the whole clock period, the time for each product (the number
of clock cycles times the clock period) is still close to half that of radix 2.

The reason radix 4 is so cheap is the Booth recoding. The recoded digits are in the range
{-2, -1, 0, 1, 2}, and all multiples of M in this range are obtained by shifting and
inverting. A plain (non-Booth) radix 4 multiplier would need the digit 3, and hence the
multiple 3M, which requires an extra adder.

The real trade-off appears when going beyond radix 4. Radix 8 Booth has digits in the range
{-4, ..., 4}, and so needs the "hard" multiple 3M. This requires an extra adder (or an
extra clock cycle) to precompute 3M, an extra register to store it, and a wider
multiplexer, which no longer fits in a single 6-input LUT. So radix 8 gives 33% fewer clock
cycles than radix 4, at the cost of significantly more hardware and a longer critical path.
Radix 4 is therefore the sweet spot for this kind of sequential multiplier.

## Simulation
The script `sim.sh` runs the testbench `tb_booth.vhd` using GHDL. The testbench
randomly stalls both the VALID and READY signals, and it:

* Tests all pairs of inputs for `G_DATA_SIZE` from 1 to 7.
* Tests 5000 random pairs of inputs for `G_DATA_SIZE` of 16, 17, and 32.
* Verifies the throughput of one product every `ceil(G_DATA_SIZE/2)` clock cycles, when
  there are no stalls.

## Links
* [https://en.wikipedia.org/wiki/Booth%27s_multiplication_algorithm](https://en.wikipedia.org/wiki/Booth%27s_multiplication_algorithm)
