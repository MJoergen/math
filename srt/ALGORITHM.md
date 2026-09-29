# The SRT division algorithm
This explains the radix-4
[SRT division](https://en.wikipedia.org/wiki/Division_algorithm#SRT_division)
algorithm used in this directory, and why it works. It is inspired by Ken
Shirriff's article
[Intel's \$475 million error: the silicon behind the Pentium division bug](https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html).

## Overview
Like [long division](https://en.wikipedia.org/wiki/Long_division) by hand,
SRT division produces the quotient one digit at a time. Each iteration does:
```
q := PLA(n, d)      -- select quotient digit
n := 4*(n - q*d)    -- update partial remainder
```
Here $d$ is the divisor, and $n$ is the partial remainder, which starts out as
the dividend $N$. Both are normalized first, so $1 \le d < 2$ and
$1 \le N < 2$ (or $N = 0$).

The quotient digit $q$ is one of $\lbrace -2, -1, 0, 1, 2 \rbrace$. It is selected by a
small lookup table, called the PLA after the
[programmable logic array](https://en.wikipedia.org/wiki/Programmable_logic_array)
that held it in the Pentium, even though this design does not use one. The
table only looks at the top 7 bits of $n$ and the 4 bits of $d$ after its
leading one. This works because the digit only needs to be
approximately right: a slightly wrong digit is corrected by the later digits,
as long as the partial remainder stays within $|n| \le \frac{8}{3}d$. The
sections below explain these digits, why this bound holds, and why so few
bits are enough.

## Radix 4 and the redundant digits
Radix 4 means that each iteration produces one base-4 digit of the quotient.
So the quotient gains two bits per iteration, and the partial remainder is
multiplied by 4, i.e. shifted two bits to the left. After $K$ iterations the
quotient is
```math
Q = \sum_{k=0}^{K-1} q_k \, 4^{-k},
```
where $q_k$ is the digit selected in iteration $k$. In `srt` the values are 32
bits wide (`G_SIZE = 32`), and the divider runs $K = 34$ iterations
(`G_SIZE + 2`), which gives a quotient with 2 integer bits and 66 fractional
bits.

Ordinary base-4 digits would be $\lbrace 0, 1, 2, 3 \rbrace$. SRT instead uses
the digits $\lbrace -2, -1, 0, 1, 2 \rbrace$. Since there are five of them,
storing a digit takes three bits (a sign and a two-bit magnitude), although
each digit still only adds two bits to the quotient. This digit set is *redundant* (a
[signed-digit representation](https://en.wikipedia.org/wiki/Signed-digit_representation)):
many quotients can be written in more than one way, e.g.
$1.5 = 1 + 2 \cdot 4^{-1} = 2 - 2 \cdot 4^{-1}$. This has two advantages:
* The multiples $q \cdot d$ are $0$, $\pm d$, and $\pm 2d$, which are just shifts
  of $d$. The digit 3 would require calculating $3d$.
* The digit does not have to be chosen exactly, see
  [Why 7 bits of n and 4 bits of d](#why-7-bits-of-n-and-4-bits-of-d).

The negative digits are converted to an ordinary binary quotient without any
carry chain, see [Converting the digits on the fly](#converting-the-digits-on-the-fly).

## Why the partial remainder stays bounded
**Claim:** If $|n| \le \frac{8}{3}d$, then there is a digit $q$ such that the
next partial remainder $n' = 4(n - qd)$ also satisfies $|n'| \le \frac{8}{3}d$.

**Proof:** $|n'| \le \frac{8}{3}d$ is the same as $|n - qd| \le \frac{2}{3}d$,
i.e.
```math
\left(q - \tfrac{2}{3}\right) d \;\le\; n \;\le\; \left(q + \tfrac{2}{3}\right) d .
```
For $q = -2, \ldots, 2$ these five intervals each have length $\frac{4}{3}d$,
and their centres are $d$ apart, so neighbouring intervals overlap. Together
they cover exactly $-\frac{8}{3}d \le n \le \frac{8}{3}d$. So whenever
$|n| \le \frac{8}{3}d$, at least one digit keeps the bound. Initially
$|n| = N < 2 \le \frac{8}{3}d$, so by induction the bound holds in every
iteration. $\blacksquare$

The constant $\frac{8}{3}$ is the largest bound that can be kept: If
$n > \frac{8}{3}d$, then even the largest digit $q = 2$ gives
$n' = 4(n - 2d) > n$, so the partial remainder keeps growing.

The bound also shows that the quotient is correct. Unrolling the iterations
gives $n_K = 4^K (N - Q d)$, so
```math
\left| \frac{N}{d} - Q \right| = \frac{|n_K|}{4^K d} \le \frac{8}{3} \cdot 4^{-K},
```
which is $\frac{2}{3}$ of the weight of the last digit. This is what the
[formal verification](README.md#formal-verification) checks.

## The carry-save partial remainder
Calculating $n - qd$ normally needs a carry-propagating addition across all
the bits of $n$, in every iteration. To avoid this, the partial remainder is
kept in *carry-save* form, like in the Pentium: as two numbers, the sums $s$
and the carries $c$, with $n = s + c$. Each bit of $n - qd$ is then calculated
by a [full adder](https://en.wikipedia.org/wiki/Adder_(electronics)#Full_adder)
of three bits, from $s$, $c$, and $-qd$, without any carry chain, like in a
[carry-save adder](https://en.wikipedia.org/wiki/Carry-save_adder).

The table needs $n$ itself, though. So the top 7 bits of $s$ and $c$ are added
(in the Pentium with a small
[carry-lookahead adder](https://en.wikipedia.org/wiki/Carry-lookahead_adder)),
and the result is used as the table index. This ignores the carry from the
lower bits, which can make the result one less in its last bit. So **the table
may see $n$ one row too low**: it sees either the row that $n$ is in, or the
row below. Each table entry must therefore hold a digit that is valid not just
for its own row, but also for the row above it.

The rest of this document assumes this carry-save estimate, unless it says
otherwise. `./srt.py --exact` uses an exact partial remainder instead, for
comparison.

## Why 7 bits of n and 4 bits of d
The overlap between neighbouring intervals is what allows the table to look at
only the top bits of $n$ and $d$. D. E. Atkins analysed this in detail in
[Higher-Radix Division Using Estimates of the Divisor and Partial Remainders](http://degiorgi.math.hr/aaa_sem/Div/925-934.pdf)
(IEEE Transactions on Computers, 1968). Both digit $k$ and digit $k+1$ are
allowed in the band
```math
\left(k + \tfrac{1}{3}\right) d \;\le\; n \;\le\; \left(k + \tfrac{2}{3}\right) d ,
```
which is $\frac{d}{3}$ high (green in the diagram below). The table sees $n$
rounded down to a multiple of $\Delta n$, and $d$ rounded down to a multiple of
$\Delta d$. So each table entry covers a small rectangle, $\Delta n$ high and
$\Delta d$ wide, and it must hold a digit that is allowed in the whole
rectangle. The boundary between the entries holding $k$ and $k+1$ is therefore
a staircase, which must stay inside the band.

Consider one column of the table, $d_0 \le d < d_0 + \Delta d$, and a
boundary with $k \ge 0$ (negative $k$ are symmetric). The entries
holding $k+1$ must lie above the band's lower edge, which in this column
reaches $\left(k + \frac{1}{3}\right)(d_0 + \Delta d)$. The entries holding
$k$ must lie below the band's upper edge, which in this column is at least
$\left(k + \frac{2}{3}\right) d_0$. The step must be at a multiple of
$\Delta n$ between these two values, and such a multiple always exists if the
gap between them is at least $\Delta n$. The gap is smallest for $d_0 = 1$ and
$k = 1$ (and, by symmetry, $k = -2$), which gives the condition
```math
\Delta n + \tfrac{4}{3} \Delta d \le \tfrac{1}{3} .
```
So the numbers of bits are a trade-off: a finer resolution of $d$ allows a
coarser resolution of $n$, and vice versa. With 4 bits of $d$ after the
leading one, $\Delta d = \frac{1}{16}$, and so $\Delta n \le \frac{1}{4}$ is
enough.

This design uses $\Delta n = \frac{1}{8}$, i.e. 3 fractional bits. For an exact
partial remainder this would leave a margin:
$\frac{1}{8} + \frac{1}{12} = \frac{5}{24} < \frac{1}{3}$. The carry-save
estimate uses up this margin. Since the table may see $n$ one row too low, the
estimate can be up to $2\Delta n$ below $n$, and the condition becomes
$2\Delta n + \frac{4}{3}\Delta d \le \frac{1}{3}$. 7 + 4 bits satisfy this
with equality: $\frac{2}{8} + \frac{4}{3} \cdot \frac{1}{16} = \frac{1}{4} + \frac{1}{12} = \frac{1}{3}$.
So the condition only just guarantees that a correct table exists. The
Pentium uses the same 7 + 4 bits.

The other 4 of the 7 bits are the sign and 3 integer bits, which are needed
because the bound allows $|n|$ up to $\frac{8}{3} \cdot 2 = \frac{16}{3}$. (With
this table, the partial remainder in fact stays within $-4.5 < n < 4.5$, see
[The actual range of the partial remainder](#the-actual-range-of-the-partial-remainder).)

The condition is sufficient, but not necessary: depending on how the steps
line up with the grid, even fewer bits can work. Here, the steps line up well
with the grid: in every column there is a multiple of $\frac{1}{8}$ strictly
inside the allowed range, and the smallest margin is $\frac{1}{48}$ (for $d$
between $\frac{17}{16}$ and $\frac{9}{8}$, between the digits $-2$ and $-1$).
`srt.py` checks the actual table, see [The table](#the-table). Other designs
have made other choices: according to
[Ken Shirriff's analysis](https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html),
the [MIPS R3010](https://en.wikipedia.org/wiki/R3000) used 9 bits of the
partial remainder and 9 bits of the divisor.

## The table
![Diagram of the quotient digit table](pla.svg)

The diagram shows the table in `pla.vhd`. The horizontal axis is the divisor
$d$, and the vertical axis is the partial remainder $n$.
* The red lines are the bound $|n| = \frac{8}{3}d$. The grey regions outside
  them are never reached.
* In the green bands, two neighbouring digits are both allowed.
* The blue staircases are the boundaries between the digits that the table
  selects. They stay inside the green bands. The table selects the digit by
  rounding $n/d$ to the nearest integer, so the steps follow the lines
  $n = (k + \frac{1}{2}) d$, near the middle of the bands.
* The orange rectangle is a single table entry, $\frac{1}{16}$ wide and
  $\frac{1}{8}$ high. The light orange rectangle above it is the row that the
  entry must also cover, because of the carry-save estimate.

Let $n_0$ and $d_0$ be the values that the table sees. Because of the
[carry-save estimate](#the-carry-save-partial-remainder), each entry must hold
a digit that is valid for $n$ in $[n_0, n_0 + \frac{1}{4})$ (its own row and
the row above) and $d$ in $[d_0, d_0 + \frac{1}{16})$. The table in `pla.vhd`
therefore rounds $n/d$ at the centre of this region,
$n = n_0 + \frac{1}{8}$ and $d = d_0 + \frac{1}{32}$. In units of
$\frac{1}{32}$ these are the integers $n_v = 32 n_0 + 4$ and
$d_v = 32 d_0 + 1$ (as in `get_q` in `pla.vhd`), and
```math
|q| = \begin{cases} 0 & \text{if } 2|n_v| < d_v \\ 1 & \text{if } d_v < 2|n_v| < 3d_v \\ 2 & \text{if } 3d_v < 2|n_v| \end{cases}
```
with the sign of $n_0$. Here $2|n_v|$ is even, and $d_v$ and $3d_v$ are odd, so
there are no ties. A table that works with the carry-save estimate also works
with an exact partial remainder, since each entry then only needs to be valid
for its own row. `./srt.py` checks the table and tests divisions with a
carry-save partial remainder, and `./srt.py --exact` with an exact one.

There is little room for other choices, since the carry-save condition above
is met with equality. For instance, rounding at the centre of a single table
entry, $n = n_0 + \frac{1}{16}$, gives a table that works for an exact partial
remainder, but fails for 2 entries with carry-save. Rounding at the corner of
the entry, $n = n_0$ and $d = d_0$ (using $|n_0|$), fails for 18 entries with
carry-save.

The staircases are generated from the table by `./srt.py --tikz`, and the
diagram is built from `pla.tex` with `make pla.svg`.

## The actual range of the partial remainder
The bound $|n| \le \frac{8}{3}d$ holds for any valid table. For the table in
`pla.vhd`, the partial remainder actually stays within $-4.5 < n < 4.5$. This
can be shown directly, for any precision of $n$ and $d$.

The divisor does not change during a division, so consider a fixed $d$, i.e. a
fixed column of the table. In this column, let $t_k$ be the smallest $n$ (a
multiple of $\frac{1}{8}$) where the table selects a digit larger than $k$, for
$k = -2, \ldots, 1$. So the table selects the digit $q$ when it sees $n$ in
$t_{q-1} \le n < t_q$. Since the table may see $n$ one row too low, the digit
$q$ is used for $t_{q-1} \le n < t_q + \frac{1}{8}$. In this range, the next
partial remainder $n' = 4(n - qd)$ increases with $n$, so it is largest just
below $t_q + \frac{1}{8}$:

| Digit     | Range of $n$                              | Next partial remainder                   |
| --------- | ----------------------------------------- | ---------------------------------------- |
| $q = -2$  | $n < t_{-2} + \frac{1}{8}$                | $n' < 4(t_{-2} + \frac{1}{8} + 2d)$      |
| $q = -1$  | $t_{-2} \le n < t_{-1} + \frac{1}{8}$     | $n' < 4(t_{-1} + \frac{1}{8} + d)$       |
| $q = 0$   | $t_{-1} \le n < t_0 + \frac{1}{8}$        | $n' < 4(t_0 + \frac{1}{8})$              |
| $q = 1$   | $t_0 \le n < t_1 + \frac{1}{8}$           | $n' < 4(t_1 + \frac{1}{8} - d)$          |
| $q = 2$   | $t_1 \le n < U$                           | $n' < 4(U - 2d)$                         |

Let $U$ be the largest of 2 (the dividend is less than 2) and the limits in
the first four rows. Then $4(U - 2d) \le U$, as long as $U \le \frac{8}{3}d$,
so by induction $n < U$ in every iteration. The lower limit $L$ is found the
same way, from the smallest values in each range. Each limit is linear in $d$,
so within a column the extremes are at the ends of the column. Calculating
this for all 16 columns gives $-4.5 < n < 4.5$. (With an exact partial
remainder, the ranges end at $t_q$ instead, which gives $-4.5 < n < 4$.)
`./srt.py --bounds` (and `./srt.py --bounds --exact`) confirms these limits
numerically for each column, by extending the range of $n$ until it no longer
changes.

Both limits come from the last column, $\frac{31}{16} \le d < 2$, where
$t_{-2} = -3$, $t_{-1} = -1$, $t_0 = \frac{7}{8}$, and $t_1 = \frac{23}{8}$:
* A partial remainder of $\frac{7}{8}$ (or just above) gets the digit $q = 1$,
  which gives $n' = 4(n - d) > 4\left(\frac{7}{8} - 2\right) = -4.5$. Likewise
  $n = \frac{23}{8}$ gets $q = 2$, which gives
  $n' > 4\left(\frac{23}{8} - 4\right) = -4.5$.
* A partial remainder just below $-\frac{7}{8}$ is in the row where the table
  holds $q = 0$. But the table may see it in the row below, and then selects
  $q = -1$, which gives $n' = 4(n + d) < 4\left(-\frac{7}{8} + 2\right) = 4.5$.
  Likewise for $n$ just below $-\frac{23}{8}$ and $q = -2$.

These limits are approached, but never reached. With `G_SIZE=16`, the model
finds partial remainders from $-4.499$ (dividing `0x1003` by `0x1FFF`) up to
$4.354$ (dividing `0x116B` by `0x1FFF`). The upper limit needs the table to see
$n$ one row too low at the right moment, which is rare. (`srt.py` has no
option for `G_SIZE`. These results come from calling its function `srt_core`
directly with `g=16` and the normalized inputs, e.g.
`srt_core(0x116B, 0x1FFF, build_table(), g=16, trace=[])`.)

So the range is a property of this particular table, and of the carry-save
estimate. For $n_0 = \frac{7}{8}$ and $d$ in the last column the table selects
$q = 1$, since it rounds
$\left(\frac{7}{8} + \frac{1}{8}\right) / \left(\frac{31}{16} + \frac{1}{32}\right) = \frac{32}{63} \approx 0.51$,
even though $n/d \approx 0.44$ (for $d$ close to 2) would round to 0. That
digit is allowed, but it moves the next partial remainder further out. A table
that selected the digit by rounding the exact value of $n/d$ would keep
$|n'| \le 2d < 4$.

The range also shows which table entries are never used: those outside the
range of their column. This is why the table check in `srt.py`, which only
uses the bound $|n| \le \frac{8}{3}d$, flags some entries near the edge that
are never used.

## Implementation
This section describes two ways in which `srt_core.vhd` avoids long carry
chains, which would limit the clock frequency.

### Converting the digits on the fly
Appending a negative digit to the quotient would normally require a
subtraction, i.e. a carry chain. Instead, this design converts the digits to
an ordinary binary number *on the fly*, a technique described by Ercegovac and
Lang in
[On-the-Fly Conversion of Redundant into Conventional Representations](https://doi.org/10.1109/TC.1987.1676986)
(IEEE Transactions on Computers, 1987). Two registers hold the quotient so
far, $Q$, and $Q - 1$ (in units of the last digit). Since
$4Q + q = 4(Q - 1) + (4 + q)$, a negative digit is appended to $Q - 1$
instead. In the table below, & means appending two bits:

| $q$  | New $Q$           | New $Q - 1$       |
| ---- | ----------------- | ----------------- |
| 2    | $Q$ & `10`        | $Q$ & `01`        |
| 1    | $Q$ & `01`        | $Q$ & `00`        |
| 0    | $Q$ & `00`        | $Q - 1$ & `11`    |
| -1   | $Q - 1$ & `11`    | $Q - 1$ & `10`    |
| -2   | $Q - 1$ & `10`    | $Q - 1$ & `01`    |

So each iteration only selects one of the two registers and appends two bits,
without any carry chain, and after the last iteration $Q$ is the quotient.

In `srt_core.vhd` each digit is first stored in a register, and only appended in
the next iteration, and the quotient output is $Q$ with the stored digit
appended. This keeps the many quotient registers off the output of the table,
which is on the critical path.

### Selecting the digit with two comparisons
The thresholds $t_k$ from
[The actual range of the partial remainder](#the-actual-range-of-the-partial-remainder)
also give a faster way to implement the table. The table rounds
$(n_0 + \frac{1}{8})/d$, where $n_0$ is the value of $n$ that it sees, for
positive and negative $n_0$ alike. So in every column
$t_{-1} = -t_0 - \frac{1}{8}$ and $t_{-2} = -t_1 - \frac{1}{8}$ (e.g. in the
last column $t_0 = \frac{7}{8}$ and $t_{-1} = -1$), and within a column, the
magnitude of the digit only depends on $m = |n_0 + \frac{1}{8}|$:
```math
|q| = \begin{cases}
0 & \text{for } m < t_0 + \frac{1}{8}
\\ 1 & \text{for } t_0 + \frac{1}{8} \le m < t_1 + \frac{1}{8}
\\ 2 & \text{for } t_1 + \frac{1}{8} \le m
\end{cases}
```
and its sign is the sign of $n_0$. In units of $\frac{1}{8}$, $m = n_0 + 1$
for $n_0 \ge 0$, and $m = -n_0 - 1$ (the
[one's complement](https://en.wikipedia.org/wiki/Ones%27_complement) of
$n_0$) for $n_0 < 0$.

The divisor does not change during a division, so `srt_core.vhd` looks up $t_0$
and $t_1$ for its column when the division starts, and stores them in a
register. Each iteration then only compares $m$ against these two values.
In the FPGA, each comparison is a short carry chain on the 7 bits of $n_0$,
with the inverted sign as carry in, which is much faster than a lookup that
depends on all 11 bits. The digit selection and the update of the partial
remainder must both fit in one clock cycle, so this matters for the clock
frequency. `pla.vhd` checks that the comparisons give the same digit as the
table for all 2048 entries.

The original Pentium table cannot be implemented like this, since it holds 0
above the $q = 2$ region, and its upper edge is not the same for positive and
negative $n$. So `pla_pentium.vhd` (see below) uses a lookup in the table.

## The Pentium FDIV bug
The [FDIV bug](https://en.wikipedia.org/wiki/Pentium_FDIV_bug) was found in
1994. Coe, Mathisen, Moler, and Pratt tell the story of how it was found in
[Computational Aspects of the Pentium Affair](https://people.cs.vt.edu/~naren/Courses/CS3414/assignments/pentium.pdf)
(IEEE Computational Science and Engineering, 1995).

In the Pentium, the table's unused entries held 0. In 1994 Intel stated, in
its white paper
[Statistical Analysis of Floating Point Flaw in the Pentium Processor](https://www.ardent-tool.com/CPU/Intel/fdiv/white11.pdf),
that the bug was caused by five entries that were omitted from the table.
[Ken Shirriff's analysis](https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html)
shows that in fact 16 entries were missing, one in each column, along the top
edge of the $q = 2$ region: they overlap the region $|n| \le \frac{8}{3}d$, so
they should have held 2, but they held 0. Its explanation is that the table
was generated with the wrong bound line for that edge. To allow for the
carry-save estimate, some of the bound lines must be moved down by
$\frac{1}{8}$, namely those where this makes the allowed region smaller. The
top edge is not one of them, but it was moved down anyway.

Only five of the 16 missing entries can be reached by a division, and only
because of the carry-save estimate: `./srt.py --bounds --pla pentium` shows
that the partial remainder is unbounded in exactly these five columns. Even
these five entries are only reached in about 1 in 9 billion random divisions,
according to Intel's white paper.

The fix filled all the unused entries above the $q = 2$ region and below the
$q = -2$ region with 2, which also made the PLA smaller.

### Both Pentium tables in this divider
[`pla_pentium.vhd`](pla_pentium.vhd) holds the Pentium's table, both the
original and the fixed version, copied from the article. The five reachable
missing entries are marked there. It can replace `pla.vhd` with the generic
`G_PLA` of `srt_core.vhd`, e.g. `make sim PLA=pentium`. The Pentium's table
picks the larger digit where both are allowed, so with the fixed table the
partial remainder has a larger range: $-5 < n < 5$.

Since `srt_core.vhd` keeps the partial remainder in carry-save form like the
Pentium, the original table gives this divider the FDIV bug too. With
`PLA=pentium`, the testbench verifies that 4195835/3145727 gives
$1.3337390688$ instead of $1.3338204492$, the famous wrong result of the
Pentium. The model shows how this happens:
```
./srt.py 4195835 3145727 --pla pentium --trace
```
With an exact partial remainder, $n$ never gets this high in the column of
this divisor ($d = 1.0111\ldots$ in binary), but the carry-save estimate lets
it climb to the row $3.875$, which holds one of the five missing entries. In
iteration 7, $n = 3.986$ is in this row, but the table sees it one row too
low, as $3.75$, and still selects $q = 2$. In iteration 8, $n = 3.943$ is in
the same row, and this time the table sees it in its own row. So it hits the
missing entry, and selects $q = 0$ instead of $2$. The next partial remainder,
$4n \approx 15.8$, overflows the 4 integer bits, and the quotient never
recovers. With the fixed
table (`PLA=pentium_fixed`, or `--pla pentium_fixed`) the result is correct.

The bug needs the carry-save partial remainder. With an exact partial
remainder, even the original table gives correct results:
`./srt.py --pla pentium --exact` shows that the table check fails for 21
entries along the top edge, and that each of them is outside the range of the
partial remainder. These are the 16 missing entries, which overlap the region
$|n| \le \frac{8}{3}d$ only in a small corner, and 5 more entries that touch
it at a single corner point.
