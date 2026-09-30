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

Why this works: After k iterations, the partial product P, together with the
2k bits that have been shifted into the Q field, equals M times the low 2k bits
of Q, read as a signed number. This follows by induction, since the recoded
digits of the low 2k bits of Q add up to exactly that signed number. After the
last iteration, the low bits of Q are all of Q, so the result is M*Q. This
invariant is also what the formal verification checks in every clock cycle,
see [`booth.psl`](booth.psl).

Since 2M is just M shifted one bit to the left, only a single adder is needed.
The operand (0, M, or 2M) is selected first, and subtraction is performed by
inverting the operand and setting the carry input of the adder. The operand is
selected one clock cycle in advance, see [Timing](#timing).

P is two bits wider than M, so that the operation P - 2M does not overflow when
M is the most negative number, i.e. `-2^(G_DATA_SIZE-1)`.

## Radix 2 versus radix 4
To compare the two options, [`booth_radix2.vhd`](booth_radix2.vhd) implements
radix 2 with the same interface, the same output register, and the same
single-adder structure. Only the parts that depend on the radix are different:
it examines two bits in each iteration, shifts one bit, and P is only one bit
wider than M.

### Resource usage
Estimated with [Yosys](https://github.com/YosysHQ/yosys) 0.69 (`synth_xilinx`,
for Xilinx 7-series FPGAs), by running `make synth`:

| `G_DATA_SIZE` | Clock cycles | LUT       | FF        | CARRY4  | Logic levels |
| ------------- | ------------ | --------- | --------- | ------- | ------------ |
|  8            |  8 /  4      |  33 /  63 |  55 /  54 |  4 /  4 |  4 /  4      |
| 16            | 16 /  8      |  57 /  90 | 104 / 103 |  7 /  6 |  6 /  6      |
| 32            | 32 / 16      | 106 / 170 | 201 / 200 | 11 / 11 | 10 / 10      |
| 64            | 64 / 32      | 202 / 331 | 394 / 393 | 19 / 19 | 18 / 18      |

Each entry is radix 2 / radix 4. LUT, FF, and CARRY4 are the numbers of cells
in the whole design. "Logic levels" is the largest number of LUT and CARRY4
cells on any path between two registers, as Vivado counts logic levels. They
are the CARRY4 cells of the adder's carry chain, plus one LUT.

### Performance
Radix 4 needs half as many clock cycles for each product. This halves the
latency and doubles the throughput, for the same clock frequency.

### Utilization
The two options use the same number of flip-flops and CARRY4 cells, but radix 4
needs more LUTs:

* FF: The partial product P is one bit wider in radix 4, but the iteration
  counter is one bit narrower. For odd `G_DATA_SIZE`, the multiplier Q is also
  one bit wider. The net difference is at most one or two flip-flops.
* Adder: Both use a single adder, of width `G_DATA_SIZE+1` and `G_DATA_SIZE+2`
  respectively. The number of CARRY4 cells is almost the same. The small
  difference is due to rounding, and to the smaller iteration counter in radix
  4.
* LUT: Radix 4 must additionally choose between M and 2M. But 2M is just M
  shifted one bit to the left, so this is just a 2-to-1 multiplexer on each bit,
  and no extra adder is needed. Still, the operand selection for each bit is a
  function of M(i), M(i-1), Q(1), Q(0), and Q(-1), and when a new pair of
  inputs is accepted, of the corresponding input bits instead. In radix 2 this
  fits into one LUT for each bit, but not in radix 4. So radix 4 uses about 60%
  more LUTs in the table above. With Vivado the difference is about 30%.

### Timing
The critical path is the same in both cases: From the registers, through a
single LUT (P(i) XOR the operand bit), through the carry chain of the adder, and
back into the working register. The carry chain is one bit longer in radix 4.
In the table above, both designs have the same number of logic levels for
every `G_DATA_SIZE`.

The operand selection logic is not on the critical path, because the operand
is selected one clock cycle in advance, and stored in a register (`opd`). This
is possible because the bits of Q that select the operand are never changed by
the adder: They are shifted down from higher bits of Q, which are only
overwritten by the low bits of P after they have been used. The register costs
`G_DATA_SIZE+2` (radix 2) or `G_DATA_SIZE+3` (radix 4) flip-flops, but it
makes the adder depend only on registers next to it. Without it, Q(1), Q(0),
and Q(-1) would have to be routed to every bit of the adder in the same clock
cycle, which costs about 0.5 ns of routing delay.

So the carry chain is the bottleneck: Its delay grows by about 0.1 ns for every
4 bits (one CARRY4 cell). With Vivado 2025.1 and the Artix-7 part of
`make vivado`, the maximum clock frequency of radix 4 is roughly 420 MHz for
`G_DATA_SIZE=16`, 365 MHz for 32, and 285 MHz for 64, and about the same for
radix 2.

Because the operand selection has its own register stage, this also holds on
an FPGA with 4-input LUTs, where the operand selection of radix 4 needs two
levels of LUTs, as long as these are faster than the carry chain.

### Trade-off
There is hardly any trade-off: Radix 4 gives twice the performance for some
more LUTs, but the same number of flip-flops and the same number of logic
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

## Carry-save version
In `booth.vhd`, the critical path is the carry chain of the adder, which
grows with `G_DATA_SIZE`, see [Timing](#timing). And each clock cycle handles
only two bits of Q. [`booth_csa.vhd`](booth_csa.vhd) removes both limits.
Instead of a higher radix, which would need the hard multiple 3M, it handles
several radix 4 digits (`G_DIGITS`) in each clock cycle.

### Carry-save form
P is kept as the sum of two vectors, s and c. Adding an operand to s + c is
done with a 3:2 compressor: a full adder for each bit, whose sum bits form
the new s, and whose carry bits (shifted one bit to the left) form the new c.
There is no carry chain, so this is one LUT level for every bit, however wide
P is. With k = `G_DIGITS`, each iteration adds k operands (operand j shifted
2*j bits to the left) with k compressors in a tree, i.e. about log1.5(k+2)
LUT levels.

The low 2*k bits of the result are shifted out of P, into the product. They
are added (with a small 2*k bit adder, and a carry into the next iteration)
in the next clock cycle, so that this adder is not in series with the
compressors.

Two details make this work for signed numbers:
* **Bias:** s and c cannot be sign-extended individually. So the design
  stores P + B instead of P, where B = 2^(`G_DATA_SIZE`+1), which is never
  negative. Each operand is added with the bias 3B (inverting its MSB and
  prepending a one). The k biases add up to (4^k - 1)*B, so after the shift by
  2*k bits the bias is B again, and the bits shifted out are unchanged. So all
  the vectors are non-negative, and are simply shifted with zeros.
* **Subtraction:** A negative operand is the inverted operand plus one. For
  operand j, the one belongs at bit 2*j. It is split into 4^j - 1 (the free
  bits below operand j, all set to one) and 1 (the free LSB of the carry
  vector of compressor j). So no extra vector is needed.

### Final addition
After the last iteration, s and c must be added to give the upper bits of the
product. This is done by a carry-select adder in two clock cycles:
1. The bits are split into blocks of `G_CPA_SIZE` bits. Each block is added
   twice, with carry input 0 and 1, giving two sums and two carry outputs.
2. The carry input of each block is found by one short addition, with one bit
   for each block. Then each block selects one of its two sums.

So the latency is `ceil(G_DATA_SIZE/(2*G_DIGITS)) + 2` clock cycles, and the
longest carry chain has `G_CPA_SIZE` bits (default 7) or one bit per block,
independently of `G_DATA_SIZE`.

### Results
Implemented with Vivado 2025.1 for the Artix-7 part of `make vivado`. The
maximum clock frequency is averaged over two or three runs with different
clock constraints, since it varies by about 5% between runs. The time is the
number of clock cycles times the clock period, i.e. the latency of a product.

| Design                   | `G_DATA_SIZE` | Clock cycles | Clock (MHz) | Time (ns) | LUT  | FF   |
| ------------------------ | ------------- | ------------ | ----------- | --------- | ---- | ---- |
| `booth.vhd`              | 16            |  8           | 420         | 19.0      |   79 |  104 |
| `booth_csa.vhd`, k=1     | 16            | 10           | 503         | 19.9      |  172 |  171 |
| `booth_csa.vhd`, k=2     | 16            |  6           | 420         | 14.3      |  244 |  196 |
| `booth_csa.vhd`, k=4     | 16            |  4           | 411         |  9.7      |  380 |  248 |
| `booth_csa.vhd`, k=8     | 16            |  3           | 355         |  8.5      |  591 |  337 |
| `booth.vhd`              | 32            | 16           | 365         | 43.8      |  144 |  201 |
| `booth_csa.vhd`, k=1     | 32            | 18           | 408         | 44.1      |  325 |  326 |
| `booth_csa.vhd`, k=2     | 32            | 10           | 415         | 24.1      |  441 |  370 |
| `booth_csa.vhd`, k=4     | 32            |  6           | 399         | 15.0      |  701 |  454 |
| `booth_csa.vhd`, k=8     | 32            |  4           | 334         | 12.0      | 1551 |  628 |
| `booth.vhd`              | 64            | 32           | 285         | 112       |  274 |  394 |
| `booth_csa.vhd`, k=1     | 64            | 34           | 395         | 86.1      |  629 |  636 |
| `booth_csa.vhd`, k=2     | 64            | 18           | 367         | 49.0      |  848 |  711 |
| `booth_csa.vhd`, k=4     | 64            | 10           | 386         | 25.9      | 1329 |  859 |
| `booth_csa.vhd`, k=8     | 64            |  6           | 311         | 19.3      | 2478 | 1166 |

k is `G_DIGITS`, and `G_CPA_SIZE` is 7. The throughput is one product per
latency (the clock cycles above), for all designs.

The resource usage estimated with Yosys (`make synth`, with the default
`G_DIGITS=4`) is:

| `G_DATA_SIZE` | LUT  | FF  | CARRY4 | Logic levels |
| ------------- | ---- | --- | ------ | ------------ |
|  8            |  159 | 133 | 11     | 4            |
| 16            |  389 | 241 | 16     | 4            |
| 32            |  722 | 439 | 29     | 4            |
| 64            | 1398 | 832 | 44     | 5            |

The number of logic levels hardly depends on `G_DATA_SIZE`, unlike for
`booth.vhd` (see [Resource usage](#resource-usage)).

### Trade-off
* With one digit per clock cycle (k=1), the carry-save form alone does not
  help much: The clock frequency no longer depends on `G_DATA_SIZE`, but the
  final addition adds two clock cycles, so it only pays off for
  `G_DATA_SIZE=64`.
* The real gain is that more digits per clock cycle are now cheap: Each extra
  digit costs about one more compressor (one LUT for each bit), instead of
  another carry chain in series. Up to k=4 the clock frequency stays at about
  400 MHz, so the time for a product drops almost in proportion to k.
* At k=8 the compressor tree (4 LUT levels) becomes the critical path, and
  the clock frequency drops to about 310-355 MHz. This still gives the shortest time, but it doubles the number
  of LUTs compared to k=4.
* The number of LUTs grows about linearly with k and with `G_DATA_SIZE`,
  since there are k operands of `G_DATA_SIZE+3` bits each. k=4 is a good
  compromise: 2 to 4 times shorter time than `booth.vhd`, for about 5 times
  as many LUTs.

What limits the clock frequency now are the short carry chains (in the final
addition, and in the addition of the low bits), which take about 2.2-2.5 ns
from register to register even with only 2 or 3 CARRY4 cells, because of the
routing into and out of the chain.
