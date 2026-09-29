# Booth's multiplication algorithm
This explains the radix 4
[Booth's algorithm](https://en.wikipedia.org/wiki/Booth%27s_multiplication_algorithm)
used in [`booth.vhd`](booth.vhd), and compares it with the radix 2 version in
[`booth_radix2.vhd`](booth_radix2.vhd).

## Booth recoding
Let M be the multiplicand (`s_a_i`) and Q be the multiplier (`s_b_i`), both
signed ([two's complement](https://en.wikipedia.org/wiki/Two%27s_complement)).
Like long multiplication by hand, the product is calculated by adding shifted
multiples of M, one for each digit of Q.

Booth's algorithm first recodes Q. A run of ones in the multiplier, e.g.
`0011110`, has the value `0100000 - 0000010`. So instead of one addition for
each bit set, there is only a subtraction at the start of the run and an
addition at the end of the run. In the original (radix 2) Booth algorithm, each
iteration examines two bits, Q(0) and Q(-1), where Q(-1) is the bit to the
right of Q(0) (initially zero). The recoded digit is `Q(-1) - Q(0)`, so the
only operations are 0, +M, and -M.

Radix 4 combines two such radix 2 steps into a single step, and examines three
bits, Q(1), Q(0), and Q(-1). The recoded digit is
`(Q(-1) - Q(0)) + 2*(Q(0) - Q(1)) = Q(-1) + Q(0) - 2*Q(1)`, which is in the
range {-2, -1, 0, 1, 2}. All these multiples of M are obtained by shifting and
inverting, see [Theory of operation](#theory-of-operation).

## Theory of operation
If `G_DATA_SIZE` is odd, then Q is sign-extended by one bit, so that it has an
even number of bits. A working register is formed by concatenating P (the
partial product, initially zero), Q, and an extra bit Q(-1) (initially zero):

`prod = P & Q & Q(-1)`

In each of `ceil(G_DATA_SIZE/2)` iterations, the three least significant bits
of the working register, Q(1), Q(0), and Q(-1), are examined:

| Q(1) Q(0) Q(-1) | Recoded digit | Operation   |
| --------------- | ------------- | ----------- |
| 000             |  0            | No change   |
| 001             | +1            | P := P + M  |
| 010             | +1            | P := P + M  |
| 011             | +2            | P := P + 2M |
| 100             | -2            | P := P - 2M |
| 101             | -1            | P := P - M  |
| 110             | -1            | P := P - M  |
| 111             |  0            | No change   |

Then the entire register is shifted two bits to the right (arithmetic shift).
After `ceil(G_DATA_SIZE/2)` iterations the product is the low `2*G_DATA_SIZE`
bits of `P & Q`. The upper bits are just sign extension.

Since 2M is just M shifted one bit to the left, only a single adder is needed.
The operand (0, M, or 2M) is selected first, and subtraction is performed by
inverting the operand and setting the carry input of the adder.

P is two bits wider than M, so that the operation P - 2M does not overflow when
M is the most negative number, i.e. `-2^(G_DATA_SIZE-1)`.

## Radix 2 versus radix 4
To compare the two options, [`booth_radix2.vhd`](booth_radix2.vhd) implements
radix 2 with the same interface, the same output register, and the same
single-adder structure. Only the parts that depend on the radix are different:
it examines two bits in each iteration, shifts one bit, and P is only one bit
wider than M.

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
