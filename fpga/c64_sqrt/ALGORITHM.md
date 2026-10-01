# Digit-by-digit square root
This explains how [`c64_sqrt.vhd`](c64_sqrt.vhd) calculates the square root
of a C64 floating point number, using the
[digit-by-digit method](https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2))
in its non-restoring form, why the result is always correctly rounded, and
how the number of iterations in each clock cycle (`G_STEPS`) affects the
latency.

## Reducing to a radicand in [0.25, 1)
A C64 floating point number (see [README.md](../README.md#c64-floating-point-format)) has
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
  $2^{-33}$), i.e. 33 iterations. The first bit is always set, since
  $x \ge \frac{1}{4}$, so the first iteration is done when the input is
  accepted: bit 33 is set, and the remainder is $x - \frac{1}{4}$. The other
  32 iterations are done `G_STEPS` at a time, see
  [Several iterations in each clock cycle](#several-iterations-in-each-clock-cycle).
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
iterations, so `val` $< 2^{35}$, and 35 bits would be enough. In the
non-restoring form below, `val` can also be negative, and has 36 bits.

## The non-restoring form
As described so far, each iteration compares `val` with `mant | mask/2`, and
subtracts it only if the bit is set. This is the restoring form: The
comparison and the subtraction are two carry chains in parallel, and the new
`val` is selected by a multiplexer between them. `c64_sqrt.vhd` instead always
calculates the difference
```
diff = val - (mant | mask/2)
```
sets the bit if `diff` $\ge 0$, and keeps `2*diff` as the new `val`, also when
it is negative, i.e. the remainder is not restored. The next iteration then
corrects for this: The restored value would have been `2*val` =
`2*diff + 2*(mant | mask/2)`, so the next difference, with the next bit
`mask' = mask/2` and the same `mant`, is
```
2*diff + 2*(mant | mask/2) - (mant | mask'/2) = 2*diff + (mant | mask' | mask'/2)
```
since $2 \cdot \mathtt{mant} + \mathtt{mask} - \mathtt{mant} - \mathtt{mask}/4
= \mathtt{mant} + \frac{3}{4}\mathtt{mask}$, and `mant` has no bits at or below
`mask`. So the term is still just an OR. Each iteration is therefore a single
addition or subtraction, depending on the sign of `val`:
```
if val >= 0 then diff = val - (mant | mask/2)          -- the previous bit was set
else             diff = val + (mant | mask | mask/2)   -- it was not, so restore it
```
The bit is set if `diff` $\ge 0$, exactly as in the restoring form, so the
root is the same, bit for bit. The difference satisfies
$-2^{34} < \mathtt{diff} < 2^{34}$, since `mant | mask/2` $< 2^{34}$, so `val`
is a 36-bit signed number.

## Several iterations in each clock cycle
`c64_sqrt.vhd` does `G_STEPS` iterations in each clock cycle, i.e. `G_STEPS`
additions or subtractions in series. The bits of the root (after the first)
are calculated in 32/`G_STEPS` clock cycles, so 32 must be divisible by
`G_STEPS`. Unlike in the carry-save version of [`booth`](../booth/ALGORITHM.md),
the iterations cannot be done in parallel: In a multiplication, the digits that
select the operands are known in advance, but here each bit depends on the
sign of the previous remainder. So each iteration needs the full carry chain of
the previous one. See [Timing](#timing) for the trade-off.

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
`mask/2` would be truncated to zero in the last iteration, and in the
restoring form the comparison would be `val >= mant` instead of
`val >= mant + 1/2`. This makes the rounding
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
The state machine has three states: `IDLE_ST`, `CALC_ST` (the 32 iterations
after the first, in 32/`G_STEPS` clock cycles), and `DONE_ST`, where the
rounded result is written to the output register as soon as it is free. A new
input is accepted in the same clock cycle. So the latency is 32/`G_STEPS` + 1
clock cycles, i.e. 9 clock cycles (95 ns at 94.3 MHz) for the default
`G_STEPS=4`, and when there are no stalls a new input is accepted every
32/`G_STEPS` + 1 clock cycles.

### Timing
Each iteration is a 36-bit addition or subtraction, i.e. a carry chain of 9
CARRY4 cells. The sign at the end of the chain selects whether the next
iteration adds or subtracts, and which bits of `mant` are set, in the LUTs in
front of the next carry chain. In Vivado's timing report, each iteration takes
about 2.4 ns: about 1.2 ns in the carry chain, and about 1 ns for routing the
sign to the 36 LUTs of the next iteration. The rest of the clock period, about
1.4 ns, is the clock-to-output delay, the setup time, and the routing into the
first carry chain.

The latency for each value of `G_STEPS`, from `make vivado VIVADO_STEPS=n`
with the clock period in `c64_sqrt.xdc` reduced until the timing was no longer
met. The clock period is the shortest one where the timing is met, and the
next shorter one that was tried (in parentheses) does not meet the timing.
The LUTs and flip-flops are the numbers that `make vivado` prints:

| `G_STEPS` | Clock cycles | Clock period       | Latency | LUT | FF  |
| --------- | ------------ | ------------------ | ------- | --- | --- |
| 1         | 33           | 3.8 ns (3.7 ns)    | 125 ns  | 130 | 153 |
| 2         | 17           | 6.2 ns (6.0 ns)    | 105 ns  | 165 | 137 |
| 4         | 9            | 10.6 ns (10.4 ns)  | 95 ns   | 236 | 129 |
| 8         | 5            | 20.0 ns (19.5 ns)  | 100 ns  | 380 | 125 |
| 16        | 3            | 40 ns (38 ns)      | 120 ns  | 668 | 123 |

Each extra iteration in a clock cycle adds about 2.4 ns to the clock period,
but saves only the fixed 1.4 ns of a clock cycle. So the latency is lowest for
`G_STEPS=4`, which is the default, and the constraint in `c64_sqrt.xdc` is
10.6 ns (94.3 MHz), which is met with a slack of 0.113 ns. The critical path
then has 41 logic levels.

For comparison, the earlier restoring version of this design (one iteration in
each clock cycle, and the first iteration not done when the input is accepted)
needed 34 clock cycles of 3.85 ns, i.e. 131 ns, with 191 LUTs. Restoring
versions with 2 and 4 iterations in each clock cycle (not in this repository)
reached about 103 ns and 101 ns, with 339 and 540 LUTs: Their iterations need
an extra LUT level for the multiplexer in front of `val`.

### Resource usage
From `make vivado` with `G_STEPS=4`: 236 LUTs and 129 flip-flops (86 slices),
and no DSPs or Block RAMs. Most of the flip-flops are the registers `val`,
`mant`, and `mask`, and the output register. The LUTs are mostly the four
additions or subtractions, about 36 LUTs each.

## Trade-offs
Compared with [`c64_sqrt2`](../c64_sqrt2), which uses Goldschmidt's algorithm
with eight DSP blocks, this design is smaller (236 versus 528 LUTs, and no
DSPs) and runs at a higher clock frequency (94.3 versus 75.8 MHz). Its latency
is always 95 ns, versus 40 to 119 ns (94 ns on average). It is also always
correctly rounded, whereas `c64_sqrt2` is off by one in the last bit for about
3% of the inputs.

Some possible improvements, which are not implemented:
* **No rounding clock cycle:** The rounding needs an increment, in `DONE_ST`.
  With an extra register that holds `mant` plus the weight of the last bit
  (updated in each iteration without a carry chain, as in the on-the-fly
  conversion of [SRT division](../srt/ALGORITHM.md)), the rounding is a
  selection between two registers, and the result can be written in the last
  clock cycle of `CALC_ST`. In a prototype, this saved the clock cycle, but
  made the clock period longer, so the latency only improved for
  `G_STEPS` of 4 or more (about 91 ns for 4, and 85 ns for 8).
* **Carry-save remainder:** As in [SRT division](../srt/ALGORITHM.md), a
  redundant digit set with the remainder in carry-save form avoids the carry
  chains, since each bit is then selected from a few top bits of the
  remainder. But the routing of the selected digit to all the bits remains,
  and the exact sign of the final remainder is needed for the rounding, which
  costs a full addition at the end. The estimated gain is only 10% to 15%, for
  a much more complex design.
