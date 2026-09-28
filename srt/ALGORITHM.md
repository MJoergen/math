# The SRT division algorithm
This explains the radix-4 SRT division algorithm used in this directory, and
why it works. It is inspired by [Ken Shirriff's analysis of the Pentium division bug](https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html).

## Overview
Like long division by hand, SRT division produces the quotient one digit at a
time. Each iteration does:
```
q := PLA(n, d)      -- select quotient digit
n := 4*(n - q*d)    -- update partial remainder
```
Here $d$ is the divisor, and $n$ is the partial remainder, which starts out as
the dividend $N$. Both are normalized first, so $1 \le d < 2$ and
$1 \le N < 2$ (or $N = 0$).

The quotient digit $q$ is one of $\{-2, -1, 0, 1, 2\}$, and it is selected by
a small lookup table (`PLA`) that only looks at the top 7 bits of $n$ and the
top 4 bits of $d$ (after the leading one). This works because the digit only
needs to be approximately right: a slightly wrong digit is corrected by the
later digits, as long as the partial remainder stays within
$|n| \le \frac{8}{3}d$. The sections below explain these digits, why this
bound holds, and why so few bits are enough.

## Radix 4 and the redundant digits
Radix 4 means that each iteration produces one base-4 digit of the quotient.
So the quotient gains two bits per iteration, and the partial remainder is
multiplied by 4, i.e. shifted two bits to the left. After $K$ iterations the
quotient is
```math
q = \sum_{k=0}^{K-1} q_k \, 4^{-k},
```
where $q_k$ is the digit selected in iteration $k$. Here $K = 34$.

Ordinary base-4 digits would be $\{0, 1, 2, 3\}$. SRT instead uses the digits
$\{-2, -1, 0, 1, 2\}$. There are five of them, so storing a digit takes three
bits (a sign and a two-bit magnitude), even though each digit only contributes
a factor of 4 to the quotient. This digit set is *redundant*: many quotients
can be written in more than one way, e.g. $1.5 = 1 + 2 \cdot 4^{-1} = 2 - 2 \cdot 4^{-1}$.
This has two advantages:
* The multiples $q \cdot d$ are $0$, $\pm d$, and $\pm 2d$, which are just shifts
  of $d$. The digit 3 would require calculating $3d$.
* The digit does not have to be chosen exactly, see
  [Why 7 bits of n and 4 bits of d](#why-7-bits-of-n-and-4-bits-of-d).

Appending a negative digit to the quotient would normally require a
subtraction, i.e. a carry chain. Instead, this design converts the digits to
an ordinary binary number *on the fly*: Two registers hold the quotient so
far, $Q$, and $Q - 1$ (in units of the last digit). Since
$4Q + q = 4(Q - 1) + (4 + q)$, a negative digit is appended to $Q - 1$
instead:

| $q$  | New $Q$           | New $Q - 1$       |
| ---- | ----------------- | ----------------- |
| 2    | $Q$ & `10`        | $Q$ & `01`        |
| 1    | $Q$ & `01`        | $Q$ & `00`        |
| 0    | $Q$ & `00`        | $Q - 1$ & `11`    |
| -1   | $Q - 1$ & `11`    | $Q - 1$ & `10`    |
| -2   | $Q - 1$ & `10`    | $Q - 1$ & `01`    |

Here & means appending two bits. So each iteration only selects one of the two
registers and appends two bits, without any carry chain, and after the last
iteration $Q$ is the quotient.

In `srt_core.vhd` each digit is first stored in a register, and only appended in
the next iteration, and the quotient output is $Q$ with the stored digit
appended. This keeps the many quotient registers off the output of the table,
which is on the critical path.

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
gives $n_K = 4^K (N - q d)$, so
```math
\left| \frac{N}{d} - q \right| = \frac{|n_K|}{4^K d} \le \frac{8}{3} \cdot 4^{-K},
```
which is $\frac{2}{3}$ of the weight of the last digit. This is what the
[formal verification](README.md#formal-verification) checks.

## Why 7 bits of n and 4 bits of d
The overlap between neighbouring intervals is what allows the table to look at
only the top bits of $n$ and $d$. Both digit $k$ and digit $k+1$ are allowed in
the band
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
enough. This design uses $\Delta n = \frac{1}{8}$, i.e. 3 fractional bits,
which leaves a margin: $\frac{1}{8} + \frac{1}{12} = \frac{5}{24} < \frac{1}{3}$.
The other 4 of the 7 bits are the sign and 3 integer bits, which are needed
because the bound allows $|n|$ up to $\frac{8}{3} \cdot 2 = \frac{16}{3}$. (With
this table, the partial remainder in fact stays within $-4.5 < n < 4.5$, see
[The actual range of the partial remainder](#the-actual-range-of-the-partial-remainder).)

The condition is sufficient, but not necessary: depending on how the steps
line up with the grid, even fewer bits can work. `srt.py` checks the actual
table. Other designs have made other choices: according to
[Ken Shirriff's analysis](https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html),
the MIPS R3010 used 9 bits of the partial remainder and 9 bits of the divisor.

The Pentium uses the same 7 + 4 bits, and like this design it keeps the partial
remainder in carry-save form (a sum and a carry), to avoid a carry-propagating
addition in each iteration: each bit of $n - qd$ is calculated by a full adder
of three bits, from the sum, the carry, and $-qd$. To get the table index, the
top 7 bits of the sum and the carry are added (in the Pentium with a small
carry-lookahead adder). Since the lower bits are ignored,
the index can be one entry too low, i.e. the estimate of $n$ can be off by up
to $2\Delta n$. The condition then becomes
$2\Delta n + \frac{4}{3}\Delta d \le \frac{1}{3}$, which 7 + 4 bits satisfy
with equality: $\frac{2}{8} + \frac{4}{3} \cdot \frac{1}{16} = \frac{1}{4} + \frac{1}{12} = \frac{1}{3}$.
So the condition only just guarantees that a correct table exists. In practice
the steps line up well with the grid: in every column there is a multiple of
$\frac{1}{8}$ strictly inside the allowed range, and the smallest margin is
$\frac{1}{48}$ (for $d$ between $\frac{17}{16}$ and $\frac{9}{8}$, between the
digits $-2$ and $-1$). The table in `pla.vhd` is built for this, see
[The table](#the-table).

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
  entry must also cover, since the partial remainder is in carry-save form.

Since the partial remainder is in carry-save form (see
[Why 7 bits of n and 4 bits of d](#why-7-bits-of-n-and-4-bits-of-d)), the
table may see $n$ one row too low. So each entry must hold a digit that is
valid for its own row and the row above, i.e. for $n$ in
$[n_0, n_0 + \frac{1}{4})$ and $d$ in $[d_0, d_0 + \frac{1}{16})$, where
$n_0$ and $d_0$ are the values that the table sees. The table in `pla.vhd`
therefore rounds $n/d$ at the centre of this region,
$n = n_0 + \frac{1}{8}$ and $d = d_0 + \frac{1}{32}$. In units of
$\frac{1}{32}$ these are integers, $N = 32 n_0 + 4$ and $D = 32 d_0 + 1$, and
```math
|q| = \begin{cases} 0 & \text{if } 2|N| < D \\ 1 & \text{if } D < 2|N| < 3D \\ 2 & \text{if } 3D < 2|N| \end{cases}
```
with the sign of $n$. Here $2|N|$ is even, and $D$ and $3D$ are odd, so there
are no ties. A table that works with the carry-save estimate also works with
an exact partial remainder, since each entry then only needs to be valid for
its own row. `./srt.py` checks the table and tests divisions with a carry-save
partial remainder, and `./srt.py --exact` with an exact one.

There is little room for other choices: the carry-save condition above is met
with equality. For instance, rounding at the centre of a single table entry,
$n = n_0 + \frac{1}{16}$, gives a table that works for the exact partial
remainder, but fails for 2 entries with carry-save. The earlier version of
`pla.vhd` rounded at the corner of the entry, $n = n_0$ and $d = d_0$ (using
$|n_0|$), which fails for 18 entries with carry-save.

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

Let $U$ be the largest of the first four limits and 2 (the dividend is less
than 2). Then $4(U - 2d) \le U$, as long as $U \le \frac{8}{3}d$, so by
induction $n < U$ in every iteration. The lower limit $L$ is found the same
way, from the smallest values in each range. Each limit is linear in $d$, so
within a column the extremes are at the ends of the column. Calculating this
for all 16 columns (`./srt.py --bounds`) gives $-4.5 < n < 4.5$. (With an
exact partial remainder, the ranges end at $t_q$ instead, and
`./srt.py --bounds --exact` gives $-4.5 < n < 4$.)

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

These limits are approached, but never reached: with `G_SIZE=16` the model
finds partial remainders from $-4.499$ up to $4.354$. The upper limit needs
the table to see $n$ one row too low at the right moment, which is rare.

So the range is a property of this particular table, and of the carry-save
estimate. The table rounds $n/d$ at $n_0 + \frac{1}{8}$, to allow for the
carry-save estimate, where $n_0$ is the value of $n$ that the table sees. For
$n = \frac{7}{8}$ and $d$ in the last column this selects $q = 1$, since the
table rounds
$\left(\frac{7}{8} + \frac{1}{8}\right) / \left(\frac{31}{16} + \frac{1}{32}\right) = \frac{32}{63} \approx 0.51$,
even though $n/d \approx 0.44$ (for $d$ close to 2) would round to 0. That
digit is allowed, but it moves the next partial remainder further out. A table
that selected the digit by rounding the exact value of $n/d$ would keep
$|n'| \le 2d < 4$.

The range also shows which table entries are never used: those outside the
range of their column. This is why the table check in `srt.py`, which only
uses the bound $|n| \le \frac{8}{3}d$, flags some entries near the edge that
are never used.

## Implementing the table
The thresholds $t_k$ above also give a faster way to implement the table. The
table rounds $(n_0 + \frac{1}{8})/d$, where $n_0$ is the value of $n$ that it
sees, for positive and negative $n_0$ alike. So in every column
$t_{-1} = -t_0 - \frac{1}{8}$ and $t_{-2} = -t_1 - \frac{1}{8}$ (e.g. in the
last column $t_0 = \frac{7}{8}$ and $t_{-1} = -1$), and within a column, the
magnitude of the digit only depends on $m = |n_0 + \frac{1}{8}|$:
```math
|q| = \begin{cases}
0 & \text{for } m < t_0 + \frac{1}{8} \\
1 & \text{for } t_0 + \frac{1}{8} \le m < t_1 + \frac{1}{8} \\
2 & \text{for } t_1 + \frac{1}{8} \le m
\end{cases}
```
and its sign is the sign of $n_0$. In units of $\frac{1}{8}$, $m = n_0 + 1$
for $n_0 \ge 0$, and $m = -n_0 - 1$ (the one's complement of $n_0$) for
$n_0 < 0$.

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
In the Pentium this table was implemented as a PLA. The table's unused
entries held 0. In 1994 Intel stated that the FDIV bug was caused by five
entries that were omitted from the table.
[Ken Shirriff's analysis](https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html)
shows that in fact 16 entries were missing, along the top edge of the $q = 2$
region: they should have held 2, but held 0. Its explanation is that the table
was generated with the wrong bound line for that edge. To allow for the
carry-save estimate, some of the bound lines must be moved down by
$\frac{1}{8}$, namely those where this makes the allowed region smaller. The
top edge is not one of them, but it was moved down anyway. Only five of the 16
missing entries affect the result, and because of the carry-save adder even
these are only reached in about 1 in 9 billion random divisions.

The fix filled all the unused entries above the $q = 2$ region and below the
$q = -2$ region with 2, which also made the PLA smaller.

### Both Pentium tables in this divider
[`pla_pentium.vhd`](pla_pentium.vhd) holds the Pentium's table, both the
original and the fixed version, copied from the article. It can replace
`pla.vhd` with the generic `G_PLA` of `srt_core.vhd`, e.g. `make sim PLA=pentium`.
The Pentium's table picks the larger digit where both are allowed, so the
partial remainder has a larger range: $-5 < n < 5$.

Since `srt_core.vhd` keeps the partial remainder in carry-save form like the
Pentium, the original table gives this divider the FDIV bug too. With
`PLA=pentium`, the testbench verifies that 4195835/3145727 gives
$1.3337390688$ instead of $1.3338204492$, the famous wrong result of the
Pentium. The model shows how this happens:
```
./srt.py 4195835 3145727 --pla pentium --trace
```
In iteration 8 the partial remainder is $n = 3.943$, but the carry-save
estimate uses the row below, $3.875$. For this divisor ($d = 1.0111\ldots$ in
binary) that is one of the five missing entries, so $q = 0$ instead of $2$.
The next partial remainder is then far outside its bounds, and the quotient
never recovers. With the fixed table (`PLA=pentium_fixed`, or
`--pla pentium_fixed`) the result is correct.

The bug needs the carry-save partial remainder. With an exact partial
remainder, even the original table gives correct results:
`./srt.py --pla pentium --exact` shows that the table check fails for 21
entries along the top edge (all of them only touch the region
$|n| < \frac{8}{3}d$ at a corner), and that each of them is outside the range
of the partial remainder. (The article counts 16 missing entries: those
reached in its simulation of a carry-save divider.)
