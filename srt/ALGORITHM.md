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
this table, the partial remainder in fact stays within $-4 < n < 4.5$, see
[The actual range of the partial remainder](#the-actual-range-of-the-partial-remainder).)

The condition is sufficient, but not necessary: depending on how the steps
line up with the grid, even fewer bits can work. `srt.py` checks the actual
table. Other designs have made other choices: according to
[Ken Shirriff's analysis](https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html),
the MIPS R3010 used 9 bits of the partial remainder and 9 bits of the divisor.

The Pentium uses the same 7 + 4 bits, but it keeps the partial remainder in
carry-save form (a sum and a carry), to avoid a carry-propagating addition in
each iteration. To get the table index, it adds the top 7 bits of the sum and
the carry with a small carry-lookahead adder. Since the lower bits are ignored,
the index can be one entry too low, i.e. the estimate of $n$ can be off by up
to $2\Delta n$. The condition then becomes
$2\Delta n + \frac{4}{3}\Delta d \le \frac{1}{3}$, which 7 + 4 bits satisfy
with equality: $\frac{2}{8} + \frac{4}{3} \cdot \frac{1}{16} = \frac{1}{4} + \frac{1}{12} = \frac{1}{3}$.
So the condition only just guarantees that a correct table exists. In practice
the steps line up well with the grid: in every column there is a multiple of
$\frac{1}{8}$ strictly inside the allowed range, and the smallest margin is
$\frac{1}{48}$ (for $d$ between $\frac{17}{16}$ and $\frac{9}{8}$, between the
digits $-2$ and $-1$). This design calculates $n$ exactly in every iteration,
so its table has more precision than it needs.

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
  $\frac{1}{8}$ high.

The staircases are generated from the table by `./srt.py --tikz`, and the
diagram is built from `pla.tex` with `make pla.svg`.

## The actual range of the partial remainder
The bound $|n| \le \frac{8}{3}d$ holds for any valid table. For the table in
`pla.vhd`, the partial remainder actually stays within $-4 < n < 4.5$. This can
be shown directly, for any precision of $n$ and $d$.

The divisor does not change during a division, so consider a fixed $d$, i.e. a
fixed column of the table. In this column, let $t_k$ be the smallest $n$ (a
multiple of $\frac{1}{8}$) where the table selects a digit larger than $k$, for
$k = -2, \ldots, 1$. So the table selects the digit $q$ for
$t_{q-1} \le n < t_q$. In this range, the next partial remainder
$n' = 4(n - qd)$ increases with $n$, so it is largest just below $t_q$:

| Digit     | Range of $n$              | Next partial remainder  |
| --------- | ------------------------- | ----------------------- |
| $q = -2$  | $n < t_{-2}$              | $n' < 4(t_{-2} + 2d)$   |
| $q = -1$  | $t_{-2} \le n < t_{-1}$   | $n' < 4(t_{-1} + d)$    |
| $q = 0$   | $t_{-1} \le n < t_0$      | $n' < 4 t_0$            |
| $q = 1$   | $t_0 \le n < t_1$         | $n' < 4(t_1 - d)$       |
| $q = 2$   | $t_1 \le n < U$           | $n' < 4(U - 2d)$        |

Let $U$ be the largest of the first four limits and 2 (the dividend is less
than 2). Then $4(U - 2d) \le U$, as long as $U \le \frac{8}{3}d$, so by
induction $n < U$ in every iteration. The lower limit $L$ is found the same
way, from the smallest values in each range. Each limit is linear in $d$, so
within a column the extremes are at the ends of the column. Calculating this
for all 16 columns (`./srt.py --bounds`) gives $-4 < n < 4.5$.

The upper limit of 4.5 comes from the last column,
$\frac{31}{16} \le d < 2$, where $t_{-2} = -\frac{23}{8}$,
$t_{-1} = -\frac{7}{8}$, $t_0 = 1$, and $t_1 = 3$. A partial remainder just
below $-\frac{7}{8}$ gets the digit $q = -1$, which gives
$n' = 4(n + d) < 4\left(-\frac{7}{8} + 2\right) = 4.5$. This limit is
approached, but never reached: the model finds partial remainders up to
4.4964. The mirror case, a partial remainder just below 1 with the digit
$q = 0$, only gives $n' < 4$. The lower limit $-4$ is likewise only
approached, as $d$ approaches the upper end of a column.

So the value 4.5 is a property of this particular table. The table sees $n$
rounded down, and for a negative $n$ this rounds away from zero: $-0.876$ is
seen as $-1$. With $d$ close to 2 this selects $q = -1$, even though
$n/d \approx -0.44$ would round to 0. That digit is allowed, but it moves the
next partial remainder further out. A table that selected the digit by rounding
the exact value of $n/d$ would keep $|n'| \le 2d < 4$.

The range also shows which table entries are never used: those outside the
range of their column. This is why the table check in `srt.py`, which only
uses the bound $|n| \le \frac{8}{3}d$, flags some entries near the edge that
are never used.

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
