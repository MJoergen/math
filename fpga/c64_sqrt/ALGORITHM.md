# Digit-by-digit square root
This explains how [`c64_sqrt.vhd`](c64_sqrt.vhd) calculates the square root
of a C64 floating point number, using the
[digit-by-digit method](https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2)),
and why the result is always correctly rounded.

## Reducing to a radicand in [0.25, 1)
A C64 floating point number (see [README.md](README.md#the-number-format)) has
the value $v = m \cdot 2^{e-128}$, where $e$ is the exponent byte, and the
mantissa $m$ (with the leading one, which the sign bit replaces) is in
$[0.5, 1)$. The square root halves the exponent, which only works for an even
power of two. So the exponent is made even first:
* If $e$ is even, then $v = m \cdot 2^{e-128}$, and the radicand is $x = m$.
* If $e$ is odd, then $v = \frac{m}{2} \cdot 2^{e-127}$, and the radicand is
  $x = \frac{m}{2}$.

In both cases $x$ is in $[0.25, 1)$, and $\sqrt{v} = \sqrt{x} \cdot 2^{(e-128)/2}$
or $\sqrt{x} \cdot 2^{(e-127)/2}$. The result exponent is therefore
$(e-128)/2 + 128 = \lfloor e/2 \rfloor + \mathtt{0x40}$ (even $e$), or
$(e-127)/2 + 128 = \lfloor e/2 \rfloor + \mathtt{0x41}$ (odd $e$). Halving $m$
is just placing it one bit lower in the register `val`.

Since $x$ is in $[0.25, 1)$, the root $r = \sqrt{x}$ is in $[0.5, 1)$, which is
exactly the range of a C64 mantissa. So the result needs no normalization. A
zero input (exponent 0) gives zero, and a negative input gives zero and sets
`m_error_o`.

## The digit-by-digit method
The root $r$ is found one bit at a time, starting with the most significant
bit, like long division by hand. Let $r$ be the root found so far, and let $b$
be the weight of the next bit. The bit is set if it does not make the root too
large, i.e. if $(r + b)^2 \le x$. Since $(r + b)^2 = r^2 + 2rb + b^2$, this is
the same as
```math
x - r^2 \;\ge\; 2rb + b^2 .
```
The remainder $D = x - r^2$ is kept in a register, and when the bit is set,
$2rb + b^2$ is subtracted from it. So each bit costs one comparison and one
subtraction, and no multiplication: $2rb$ and $b^2$ are just shifts of $r$ and
$b$, since $b$ is a power of two.

**Why this is exact:** After the first $n$ bits, $r \le \sqrt{x} < r + 2^{-n}$,
i.e. $r$ is $\sqrt{x}$ truncated to $n$ bits. This follows by induction: if it
holds before the bit $b = 2^{-(n+1)}$ is decided, then setting the bit exactly
when $(r + b)^2 \le x$ keeps it. There is no approximation anywhere, unlike in
[`c64_sqrt2`](../c64_sqrt2), which uses multipliers.

As an example, take $x = 0.5$, whose root is $0.70710678\ldots$ = `0.B504F333...`
(hex) = `0.1011 0101 ...` (binary):

| Bit $b$ | $D = x - r^2$ | $2rb + b^2$ | Set? | $r$ afterwards |
| ------- | ------------- | ----------- | ---- | -------------- |
| 1/2     | 0.5           | 0.25        | yes  | 0.5            |
| 1/4     | 0.25          | 0.3125      | no   | 0.5            |
| 1/8     | 0.25          | 0.140625    | yes  | 0.625          |
| 1/16    | 0.109375      | 0.08203125  | yes  | 0.6875 = `0.1011` |

## Scaling to integers
The registers hold these values as integers:
* `mant` holds the root $r$, scaled by $2^{34}$. The bits of the root are
  calculated from bit 33 (weight $\frac{1}{2}$) down to bit 1 (weight
  $2^{-33}$), one bit in each clock cycle, i.e. 33 iterations.
* `mask` holds the bit $b$ being calculated, also scaled by $2^{34}$, i.e. it
  is one-hot, and moves one bit to the right in each iteration.
* `val` holds the remainder $D$, scaled by $2^{34+k}$ after $k$ iterations.

The growing scale of `val` is the trick that makes the comparison simple. In
iteration $k$ the bit is $b = 2^{-(k+1)}$, and the right-hand side of the
comparison, scaled like `val`, is
```math
2rb \cdot 2^{34+k} = r \cdot 2^{34} = \mathtt{mant}, \qquad
b^2 \cdot 2^{34+k} = 2^{32-k} = \mathtt{mask}/2 .
```
So the comparison is simply `val >= mant + mask/2`. Since `mant` has no bits
set at or below the position of `mask`, the addition is just an OR:
`val >= (mant or mask/2)`. After the comparison, `val` (with or without the
subtraction) is shifted one bit to the left, which is the change of scale from
$2^{34+k}$ to $2^{34+k+1}$. So `mant` never moves, and the comparison and the
subtraction always use the same bits.

The remainder satisfies $0 \le D < (r + 2^{-k})^2 - r^2 < 2^{1-k}$ after $k$
iterations, so `val` $< 2^{35}$, and 35 bits are enough.

## Rounding
The result mantissa has 32 bits (including the leading one), with weights
$2^{-1}$ down to $2^{-32}$. The 33rd bit (bit 1 of `mant`, weight $2^{-33}$) is
calculated as well, and the result is rounded up when it is set.

This gives exactly the root rounded to nearest: Let $t = \sqrt{x} \cdot 2^{33}$.
The 33-bit root is $\lfloor t \rfloor$, and rounding it up when its last bit is
set gives $\lfloor (\lfloor t \rfloor + 1)/2 \rfloor = \lfloor t/2 + 1/2 \rfloor$,
which is $\sqrt{x} \cdot 2^{32}$ rounded to nearest. There are never ties,
since $x \cdot 2^{64}$ is an integer, so $\sqrt{x} \cdot 2^{32}$ cannot be an
integer plus one half. And the rounding never overflows: the largest radicand
is $x = 1 - 2^{-32}$, whose root is $2^{32} - \frac{1}{2} - \epsilon$ in units
of $2^{-32}$, which rounds to $2^{32} - 1$, the largest mantissa.

## The last iteration
In the last iteration, $b = 2^{-33}$, and `mask/2` is bit 0. This is why the
registers have bit 0, although no bit of the root is stored there: without it,
`mask/2` would be truncated to zero in the last iteration, and the comparison
would be `val >= mant` instead of `val >= mant + 1/2`. This makes the rounding
bit wrong exactly when `val = mant`, i.e. when $x \cdot 2^{66} + 1$ is a perfect
square. Only two radicands have this property: $x = 1 - 2^{-32}$, i.e. the
largest mantissa with an even exponent (e.g. `0x80:7FFFFFFF`), and
$x = \frac{1}{4} + 2^{-33}$, i.e. the mantissa `0x00000001` with an odd
exponent (e.g. `0x81:00000001`). An earlier version of this design, with
34-bit registers, gave the wrong result for exactly these: 1 ULP too high for
the second, and for the first the rounding overflowed, so the result was half
the correct value. The testbench now calculates both.

The testbench checks the result exactly, with integers: if $M$ is the result
mantissa in units of $2^{-32}$ and $X = x \cdot 2^{64}$, the result is correct
if $(2M - 1)^2 \le 4X \le (2M + 1)^2$. Comparing with the square root in
double precision is not enough, since e.g. the root of $1 - 2^{-32}$ is only
$2^{-67}$ away from a rounding tie.

## Implementation
The state machine has three states: `IDLE_ST`, `CALC_ST` (the 33 iterations),
and `DONE_ST`, where the rounded result is written to the output register as
soon as it is free. A new input is accepted in the same clock cycle. So the
latency is 34 clock cycles, i.e. 139 ns at 244 MHz, and when there are no
stalls a new input is accepted every 34 clock cycles.

### Timing
The critical path is the 35-bit comparison `val >= (mant or mask/2)`: a carry
chain of 9 CARRY4 cells, which drives the clock enable of `mant` and the
multiplexer in front of `val`. The subtraction is a second carry chain in
parallel with it. Vivado reports 6 logic levels, and the design meets the
244 MHz constraint (4.1 ns) with a slack of 0.124 ns.

### Resource usage
From `make vivado`: 191 LUTs and 154 flip-flops (75 slices), and no DSPs or
Block RAMs. Most of the flip-flops are the three 35-bit registers `val`,
`mant`, and `mask`, and the output register. The LUTs are mostly the
comparison, the subtraction, and the multiplexer in front of `val`.

## Trade-offs
Compared with [`c64_sqrt2`](../c64_sqrt2), which uses Goldschmidt's algorithm
with eight DSP blocks, this design is much smaller (191 versus 528 LUTs, and
no DSPs) and runs at a three times higher clock frequency, but needs 34 clock
cycles instead of 3 to 9. Its latency is 139 ns, versus 40 to 119 ns. It is
also always correctly rounded, whereas `c64_sqrt2` is off by one in the last
bit for about 3% of the inputs.

Some possible improvements, which are not implemented:
* **Fewer LUTs:** The comparison and the subtraction are two carry chains.
  The comparison could instead use the sign of the subtraction, so only one
  carry chain is needed, but then the multiplexer in front of `val` would
  depend on the end of the carry chain, which adds a LUT level to the critical
  path.
* **Two bits per clock cycle:** This would halve the number of clock cycles,
  but the comparison for the second bit depends on the result of the first,
  so the critical path would contain two carry chains in series (or three
  comparisons in parallel, followed by a selection). As in
  [SRT division](../srt/ALGORITHM.md), a redundant digit set with the remainder
  in carry-save form avoids the carry chains, at the cost of converting the
  digits at the end.
