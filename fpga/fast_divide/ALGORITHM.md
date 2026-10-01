# Goldschmidt division
This explains how [`fast_divide.vhd`](fast_divide.vhd) divides two 32-bit
unsigned integers with
[Goldschmidt division](https://en.wikipedia.org/wiki/Division_algorithm#Goldschmidt_division),
why it converges so quickly, and how precise the result is.

## Normalization
Let $n$ be the numerator and $d$ the divisor. Both are shifted to the left by
the number of leading zeros of $d$, and regarded as fixed-point numbers with
the binary point 32 bits from the right:
```math
D = \frac{d \cdot 2^{z}}{2^{32}}, \qquad N = \frac{n \cdot 2^{z}}{2^{32}},
```
where $z$ is the number of leading zeros of $d$. This does not change the
quotient $N/D = n/d$, and afterwards $D$ is in $[\frac{1}{2}, 1)$. The
register `dd` holds $D$ with 36 fractional bits (the 32 bits, and 4 guard
bits), and `nn` holds $N$ with 32 integer bits and 36 fractional bits.

## The iteration
Each iteration multiplies both $N$ and $D$ by the same factor $F = 2 - D$:
```math
F := 2 - D, \qquad N := N \cdot F, \qquad D := D \cdot F .
```
This does not change the quotient. Write $D = 1 - \epsilon$. Then
$D \cdot F = (1 - \epsilon)(1 + \epsilon) = 1 - \epsilon^2$, so the distance
of $D$ from 1 is squared in each iteration. Initially $\epsilon \le \frac{1}{2}$,
so after $k$ iterations $\epsilon \le 2^{-2^k}$: $2^{-2}$, $2^{-4}$, $2^{-8}$,
$2^{-16}$, $2^{-32}$, $2^{-64}$. When $D$ has reached 1, $N$ is the quotient.
Each iteration takes a single clock cycle, with two multiplications in
parallel: $N \cdot F$ (68 by 38 bits) and $D \cdot F$ (36 by 38 bits).

The products are truncated to the width of the registers. `dd` has no integer
bit, so $D$ can never reach 1: it stops at $1 - 2^{-36}$ (all ones), since
$(1 - 2^{-36})(1 + 2^{-36}) = 1 - 2^{-72}$ is truncated to $1 - 2^{-36}$
again. The design does at most 6 iterations, and stops early when $D$ is all
ones. The check uses $D$ from before the iteration in the same clock cycle, so
one more iteration is done after $D$ has reached all ones. This multiplies $N$
by $1 + 2^{-36}$, which is the right correction for $D = 1 - 2^{-36}$.

The latency is the number of iterations plus one clock cycle for the output
register, i.e. 4 to 7 clock cycles (54 to 95 ns at 74.1 MHz). Over random
inputs (of random sizes), 62% need 7 clock cycles, 31% need 6, 7% need 5, and
0.3% need 4. In the testbench the average is 6.74.

## Rounding
`nn` has 4 more fractional bits than the result, and the result is `nn + 7`
with these 4 bits removed. Adding 8, i.e. half of the last bit of the result,
would round to nearest, so adding 7 is almost the same. Without it (i.e. with
truncation), the result is often slightly too low, e.g. 4/2 would give
1.99999999977 = `0x00000001FFFFFFFF`, since $N$ approaches the quotient from
below. With the testbench (all pairs of numerator and divisor from 1 to 100):

| Added | Too low | Too high | Integer part wrong | Largest error |
| ----- | ------- | -------- | ------------------ | ------------- |
| 0     | 4806    |  146     | 292                | 2 ULP         |
| 4     | 1886    |  298     | 0                  | 2 ULP         |
| 7     |  446    |  610     | 0                  | 2 ULP         |
| 8     |  161    |  865     | 0                  | 2 ULP         |
| 12    |    0    | 3076     | 0                  | 3 ULP         |

(From a bit-exact model of the design, which gives the same results as the
testbench for 7. An ULP is $2^{-32}$, the last bit of the result.)

## Precision
The result is a 64-bit fixed-point number, with 32 integer bits and 32
fractional bits, but it is not precise to all 64 bits. Its precision is
limited by the 36 fractional bits of $D$ and of the products:
* $D$ stops at $1 - 2^{-36}$, not at 1.
* The factors $F = 2 - D$ are calculated from the truncated $D$, so their
  product is not exactly $1/D$.
* The truncation of each product $N \cdot F$ loses up to $2^{-36}$.

So the relative error of the result is a few units of $2^{-36}$: in a
bit-exact model, over random inputs with quotients of at least 1, it is
between $-2.5 \cdot 2^{-36}$ and $+4.7 \cdot 2^{-36}$, i.e. about 34 correct
bits. In units of the last bit of the result ($2^{-32}$), the error grows with
the quotient $Q$, up to about $0.3\,Q$ ULP:

| Quotient      | Largest error (ULP) |
| ------------- | ------------------- |
| up to 100 (the testbench) | 2       |
| below $2^{8}$  | 70                 |
| below $2^{12}$ | 1101               |
| below $2^{16}$ | 14890              |
| below $2^{20}$ | 221375             |
| below $2^{24}$ | 2758718            |

The integer part of the result is still correct, with one exception: the
error is smaller than the fractional part of the quotient, which is at least
$1/d$ unless the quotient is an integer. The exception is an exact integer
quotient that comes out slightly too low. This happens when the quotient is at
least about $2^{30.9}$, which requires $d = 1$ or $d = 2$. E.g. 1969251187/1
gives 1969251186.99999999977 (`0x75606372FFFFFFFF`).

Making the result precise to $2^{-32}$ for all inputs would need about 64
correct bits instead of 34, i.e. much wider registers and multipliers, or a
final correction step: calculate the remainder $n - q \cdot d$ exactly (one
more multiplication), and correct the quotient with it. Neither is
implemented.

## Timing and resources
Both multiplications are combinational, and each iteration is a single clock
cycle. So the critical path is from `dd`, through the subtraction $F = 2 - D$,
through the 68-by-38-bit multiplier, into `nn`: 24 to 25 logic levels. The
design meets the 74.1 MHz constraint (13.5 ns) with a slack of 0.156 ns, and
this is the highest clock frequency found: with 13.25 ns the timing is not met.
It uses 12 DSP blocks for the two multipliers, 595 LUTs, and 277 flip-flops.
With the earlier constraint of 50 MHz (20 ns), the slack was 3.8 ns, and the
design used 175 flip-flops.

The normalization (counting the leading zeros of $d$, and shifting $n$ and $d$)
is done combinationally from the inputs, in the clock cycle where they are
accepted. Out of context, Vivado does not time the paths from the input ports,
so this path is not included in the timing above. In a larger design it
starts at the registers that drive the inputs.

## Trade-offs
* **Fewer DSP blocks:** Only the multiplication $N \cdot F$ needs the full
  width of $N$. The two multiplications could share a multiplier, at the cost
  of two clock cycles per iteration.
* **Pipelining:** The DSP blocks have internal pipeline registers, which would
  allow a much higher clock frequency. But each iteration depends on the
  previous one, so each iteration would then take several clock cycles, and
  the latency in nanoseconds would hardly improve.
* **Compared with SRT division:** [`srt`](../srt/ALGORITHM.md) calculates two
  bits of the quotient per clock cycle without any multipliers, so it needs 37
  clock cycles, but runs at 200 MHz, for a latency of 185 ns, and its result
  is always correctly rounded. Goldschmidt division has a lower latency (54 to
  95 ns), but needs 12 DSP blocks, and is less precise.
