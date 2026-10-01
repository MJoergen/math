# Goldschmidt's square root
This explains how [`c64_sqrt2.vhd`](c64_sqrt2.vhd) calculates the square root
of a C64 floating point number, using the form of
[Goldschmidt's algorithm](https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Goldschmidt%E2%80%99s_algorithm)
with fused multiply-add operations, and how the constants `C_ROM_SIZE` and
`C_GUARDS` trade latency and accuracy against size.

## Reducing to a radicand in [0.25, 1)
This is the same as in [`c64_sqrt`](../c64_sqrt/ALGORITHM.md#reducing-to-a-radicand-in-025-1):
the exponent is halved, and the mantissa is halved first if the exponent is
odd. So the radicand $s$ is in $[0.25, 1)$, and its root is in $[0.5, 1)$,
which is already a normalized mantissa.

## The iteration
Goldschmidt's algorithm starts from an approximation $y_0$ of $1/\sqrt{s}$,
and calculates
```math
x_0 = s \, y_0, \qquad h_0 = y_0 / 2 ,
```
and then repeats
```math
r = \tfrac{1}{2} - x h, \qquad x := x + x r, \qquad h := h + h r ,
```
until $r$ is close enough to zero. Then $x$ is $\sqrt{s}$, and $h$ is
$\frac{1}{2\sqrt{s}}$.

**Why this works:** Initially $x/h = 2s$. Each iteration multiplies both $x$
and $h$ by the same factor $1 + r$, so $x/h = 2s$ all the time. And $r$ is
defined so that $xh = \frac{1}{2} - r$. Multiplying these gives
```math
x^2 = xh \cdot \frac{x}{h} = \left(\tfrac{1}{2} - r\right) 2s = s\,(1 - 2r),
```
so $x = \sqrt{s}\sqrt{1 - 2r} \approx \sqrt{s}\,(1 - r)$, i.e. the relative error
of $x$ is about $r$. The iteration drives $r$ to zero quadratically: the new
product is $xh(1 + r)^2 = (\frac{1}{2} - r)(1 + r)^2 = \frac{1}{2} - \frac{3}{2}r^2 - r^3$,
so the new value of $r$ is
```math
r' = \tfrac{3}{2} r^2 + r^3 .
```
Each iteration roughly doubles the number of correct bits. It also shows that
$r$ never becomes negative, if it starts out non-negative.

## The initial approximation
The approximation $h_0 \approx \frac{1}{2\sqrt{s}}$ comes from a small table
(ROM), indexed by the top `C_ROM_SIZE` = 6 bits of $s$. Entry $i$ covers the
radicands $s$ in $[\frac{i}{64}, \frac{i+1}{64})$, and holds
$\frac{1}{2\sqrt{(i+1)/64}}$, rounded down to 6 bits. Using the upper end of
the interval, and rounding down, makes $h_0 \le \frac{1}{2\sqrt{s}}$, so
$x_0 h_0 = 2 s h_0^2 \le \frac{1}{2}$, and $r_0 \ge 0$. With 6 bits, $r_0$ is
at most $2^{-4.7}$ (over 200000 random inputs, in a bit-exact model of the
design).

That $r \ge 0$ matters, because the multiply-add units work with unsigned
numbers, and $r$ is used as one of the factors. The products are truncated,
which only makes $xh$ smaller and $r$ larger, so $r$ stays non-negative.

## Implementation
The calculation uses 36-bit fixed-point numbers: the 32 bits of the mantissa,
and `C_GUARDS` = 4 guard bits. [`dsp.vhd`](dsp.vhd) is a combinational
multiply-add, $a \cdot b + c$, which keeps the upper 36 bits of the 72-bit
result, so the product is truncated. The design has two of them, and the
states select their inputs:

| State        | Multiply-add unit 0   | Multiply-add unit 1   | Result                 |
| ------------ | --------------------- | --------------------- | ---------------------- |
| `INIT_ST`    |                       | $h_0 \cdot s + 0$     | $x_0 = 2 h_0 s$        |
| `CALC_R_ST`  | $x h + \frac{1}{2}$   |                       | $r = 0 - (xh + \frac{1}{2}) = \frac{1}{2} - xh$ (modulo 1) |
| `CALC_XH_ST` | $x r + x$             | $h r + h$             | new $x$ and $h$        |

The register `r` holds the radicand $s$ until `INIT_ST`, so no extra register
is needed for it.

Each iteration takes two clock cycles, since the new $x$ and $h$ depend on $r$,
which depends on the old $x$ and $h$. The iterations stop when the upper 18
bits of `r` are zero, i.e. $r < 2^{-18}$. The last `CALC_XH_ST` then calculates
$x(1 + r)$, whose relative error is $r' \approx \frac{3}{2} r^2 < 2^{-35}$,
and writes it, rounded to 32 bits, to the output register. So the latency is
$1 + 2k$ clock cycles, where $k$ is the number of values of $r$, i.e. of
iterations:

| $k$ | Latency (clock cycles) | Latency (ns) | Share of the inputs |
| --- | ---------------------- | ------------ | ------------------- |
| 1   | 3                      |  40          | very rare (mantissas close to 1, where $h_0$ is almost exact) |
| 2   | 5                      |  66          | 0.4%                |
| 3   | 7                      |  92          | 95%                 |
| 4   | 9                      | 119          | 4.8%                |

The shares are from 200000 random mantissas, in a bit-exact model of the
design. Since $r_0 \le 2^{-4.7}$, the next values are at most about $2^{-8.8}$,
$2^{-17}$, and $2^{-33}$, so there are never more than four iterations. The
testbench values give an average of 7.1 clock cycles.

## Accuracy
In exact arithmetic, the final $x$ would be within about $1.5 \cdot 2^{-36}$ of
$\sqrt{s}$. The truncation of the products adds some more error, mostly
downwards: in the bit-exact model, the final $x$ is between 3 units of
$2^{-36}$ below and 2 units above $\sqrt{s}$, i.e. within $\frac{3}{16}$ of the
last bit of the result. Rounding to 32 bits is therefore only wrong when
$\sqrt{s}$ is that close to halfway between two results, which happens for
about 3% of the inputs. The result is then off by one in the last bit, never
more. In the testbench, 464 of the 15945 results are off by one (275 too low,
and 189 too high).

The rounding never overflows: for the largest radicand, $1 - 2^{-32}$, the
result is `0xFFFFFFFF`, which is correct.

## Timing and resources
The multiply-add units are not pipelined, so the clock period must cover a
whole 36-by-36-bit multiplication and addition. Each unit is a cascade of four
DSP48E1 blocks (which are 25-by-18 bits), followed by an adder for the partial
products. Vivado reports 18 logic levels on the critical path, from the
register `r` through multiply-add unit 0. The design meets the constraint of
13.2 ns (75.8 MHz) with a slack of 0.338 ns. It uses 8 DSP blocks, 528 LUTs,
and 234 flip-flops.

## Trade-offs
The constants `C_ROM_SIZE` and `C_GUARDS` set the latency and the accuracy.
From the bit-exact model, over 20000 random inputs:

| `C_ROM_SIZE` | `C_GUARDS` | Average latency (clock cycles) | Largest latency | Wrongly rounded |
| ------------ | ---------- | ------------------------------ | --------------- | --------------- |
|  4           | 4          | 8.6                            | 9               | 2.9%            |
|  5           | 4          | 8.0                            | 9               | 3.0%            |
|  6           | 4          | 7.1                            | 9               | 3.0%            |
|  7           | 4          | 7.0                            | 7               | 3.0%            |
|  8           | 4          | 6.9                            | 7               | 3.0%            |
| 10           | 4          | 5.5                            | 7               | 3.3%            |
|  6           | 2          | 7.0                            | 9               | 11.8%           |
|  6           | 6          | 7.3                            | 9               | 0.7%            |
|  6           | 8          | 7.6                            | 9               | 0.2%            |

* **ROM size:** Each extra bit of the table halves the initial error, but a
  whole iteration is only saved when the initial error squared drops below
  the threshold. With 7 bits instead of 6, four iterations are never needed,
  so the largest latency drops from 9 to 7 clock cycles, for a table with
  twice as many entries of a few bits, i.e. a few more LUTs. Beyond that, the
  gain is small until the table is so large (10 bits) that often only two
  iterations are needed.
* **Guard bits:** More guard bits make the result more often correctly
  rounded, but need wider multipliers (and so possibly more DSP blocks and a
  longer critical path), and the iterations stop later, since the threshold
  is half the width. Correct rounding in all cases would require calculating
  the remainder $s - x^2$ to decide the last bit, i.e. another multiplication.
* **Pipelining:** The DSP blocks have internal pipeline registers, which would
  allow a clock frequency several times higher. But each multiply-add would
  then take several clock cycles, and since each step depends on the result of
  the previous one, the latency in nanoseconds would hardly improve.

Compared with [`c64_sqrt`](../c64_sqrt/ALGORITHM.md), which calculates four
bits per clock cycle with four carry chains in series, this design has a
latency of 40 to 119 ns (94 ns on average) versus always 95 ns, but needs 8
DSP blocks and about twice as many LUTs, and is not always correctly
rounded.
