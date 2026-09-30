# Pipelined square root with lookup tables
This explains how [`pipeline_sqrt.vhd`](pipeline_sqrt.vhd) calculates a
square root with two lookup tables and one multiplier, in a pipeline that
accepts a new input in every clock cycle, how precise the result is, and why
`G_EXTRA_BITS` is at most 4.

## The formula
The input $y$ is in $[1, 4)$, in fixed point 2.20 (2 integer bits and 20
fractional bits). It is split into
```math
y = a + b \, \varepsilon, \qquad \varepsilon = 2^{-9},
```
where $a$ is the top 11 bits of the input (fixed point 2.9, the table index),
and $b$ is the bottom 11 bits (fixed point 0.11, so $b$ is in $[0, 1)$). The
square root is then approximated with the
[Taylor expansion](https://en.wikipedia.org/wiki/Taylor_series) to first
order:
```math
\sqrt{y} \approx \sqrt{a} + \frac{b \, \varepsilon}{2\sqrt{a}}
          = \sqrt{a} + \frac{2}{\sqrt{a}} \cdot b \cdot \frac{\varepsilon}{4} .
```
Two tables, indexed by $a$, hold
```math
f(a) = \sqrt{a} - 1, \qquad g(a) = \frac{2}{\sqrt{a}} - 1 ,
```
which are both in $[0, 1)$, so no bits are wasted on the integer part. The
result is $1 + f(a) + (1 + g(a)) \cdot b \cdot \frac{\varepsilon}{4}$, and the
output is its fractional part, fixed point 0.22 (the integer part is always
1). So the calculation is a single multiply-add, $f + b \cdot (1 + g)$, which
fits one DSP block.

The derivative table $g$ is calculated for the middle of the interval,
$a + \frac{\varepsilon}{2}$, instead of for $a$. So the linear approximation
is close to a chord across the interval rather than a tangent at its start.
With $h = b\,\varepsilon$, its error is about
$\frac{1}{2} f''(a) \, h \, (h - \varepsilon)$ instead of $\frac{1}{2} f''(a) \, h^2$,
which reduces the largest error by a factor of 4.

## The pipeline
The calculation has two pipeline stages:
1. The table lookups. Each table has 2048 entries of 18 bits, which is one
   Block RAM (only the 1536 entries for $a$ in $[1, 4)$ are used). The lower
   11 bits of the input ($b$) are delayed alongside.
2. The multiply-add $f + b \cdot (1 + g)$ in the DSP block, whose result is the
   output register.

So the latency is 2 clock cycles (16 ns at 125 MHz), and a new input is
accepted in every clock cycle.

### The handshake
Each stage has a valid bit, and the whole pipeline shares one clock enable:
it advances when the output register is empty, or is being read
(`m_ready_i`). So when the output is not read, the pipeline stalls. The Block
RAMs and the DSP block have clock enables, so the stall costs no logic in the
data path.

`s_ready_o` must not depend combinatorially on `m_ready_i`, so it is a
register, and is only deasserted one clock cycle after the stall begins. An
input that is accepted in that clock cycle is stored in a skid buffer (one
register of 22 bits and a valid bit), and enters the pipeline when the stall
is over. While the skid buffer is full, `s_ready_o` is low. The only logic this
adds to the data path is a multiplexer in front of the table addresses, which
selects the skid buffer or the input.

## G_EXTRA_BITS
With 18 bits, the table $f$ limits the precision to about 18 bits. To improve
this, $f$ is calculated to $18 + G$ bits, where $G$ is `G_EXTRA_BITS`: the
lower 18 bits are stored in the Block RAM as before, and the upper $G$ bits in
a small separate table, which is implemented in LUTs. The upper bits are
concatenated with the result of the multiply-add, not added to it, so no
extra adder is needed.

This only works if the multiply-add never carries into the upper $G$ bits,
i.e. if $f$ never crosses a multiple of $2^{-G}$ within an interval
$[a, a + \varepsilon)$. $f(y) = \sqrt{y} - 1$ equals $j \cdot 2^{-G}$ exactly
at
```math
y = \left(1 + \frac{j}{2^G}\right)^2 = \frac{(2^G + j)^2}{2^{2G}} ,
```
which is a multiple of $2^{-2G}$. For $G \le 4$ this is a multiple of
$\varepsilon = 2^{-9}$, i.e. a table index itself, so $f$ only crosses the
multiples of $2^{-G}$ at the start of an interval, and there is never a
carry. For $G = 5$ the first crossing, $y = \frac{33^2}{2^{10}} = 1.0634765625$,
lies in the middle of an interval, and indeed the result is wrong just above
it: the input `0x110401` gives `0x000001` instead of `0x020001`. So
`G_EXTRA_BITS` must be at most 4.

## Precision
The testbench compares the result with the exact square root, rounded down to
22 bits. The largest difference is $2^{4-G} + 1$ units of $2^{-22}$ (the last
bit of the output), which the error sources below explain exactly:

| `G_EXTRA_BITS` | Largest error | Accuracy |
| -------------- | ------------- | -------- |
| 0              | 0x11 (17)     | 18 bits  |
| 1              | 0x9           | 19 bits  |
| 2              | 0x5           | 20 bits  |
| 3              | 0x3           | 21 bits  |
| 4              | 0x2           | 21 bits  |

The errors come from:
* **The table f:** Its values are rounded down to $18 + G$ bits, i.e. by up
  to $2^{-(18+G)}$, which is $2^{4-G}$ units of $2^{-22}$. This is the main
  part for small $G$.
* **The output:** The result of the multiply-add is truncated to 22 bits,
  which is up to 1 more unit.
* **The linear approximation:** Its error is at most
  $\frac{1}{8} |f''| \varepsilon^2 \le 2^{-23}$ (with $|f''| = \frac{1}{4} a^{-3/2} \le \frac{1}{4}$),
  i.e. half a unit, and it is smaller than this for most inputs. Since
  $\sqrt{y}$ is concave, the approximation is below the correct value, like
  the two errors above.
* **The table g:** Its values are rounded to 18 bits, but they are multiplied
  by $b \cdot \frac{\varepsilon}{4} < 2^{-11}$, so this is negligible.

The first two add up to the largest errors in the table. See the tables under
[Test results](README.md#test-results) for the inputs where they occur.

## Timing and resources
Both stages are just registers around a Block RAM and a DSP block, so the
critical path, from the output of the Block RAM into the DSP block, has no
logic at all. The design meets the constraint of 8 ns (125 MHz) with a slack
of at least 1.7 ns for all values of `G_EXTRA_BITS`. With a shorter clock
period of 7.5 ns or less, Vivado implements some or all of the tables in LUTs
instead of Block RAM (e.g. 807 LUTs and no Block RAM at 6 ns), so the clock
period cannot be reduced much without extra pipeline registers in the Block
RAMs.

The design uses 2 Block RAMs, 1 DSP block, and 29 to 47 LUTs and 25 to 33
flip-flops, depending on `G_EXTRA_BITS`. About 29 LUTs and 25 flip-flops are
for the handshake (the skid buffer, the valid bits, and the clock enable), and
the rest is the table of the upper bits of $f$.

## Trade-offs
* **Table size versus precision:** Each extra bit of the table index halves
  $\varepsilon$, which reduces the approximation error by a factor of 4, but
  doubles the size of the tables. With 11 bits the approximation error is
  already below the rounding errors, so the precision is limited by the width
  of the table $f$, which `G_EXTRA_BITS` extends cheaply up to 4 bits.
* **Second order:** A second-order Taylor term would allow a much smaller
  table (and so LUTs instead of Block RAMs), but needs a third table and a
  second multiplier.
* **Compared with the iterative designs:** [`c64_sqrt`](../c64_sqrt) and
  [`c64_sqrt2`](../c64_sqrt2) calculate a 32-bit result, correctly rounded or
  almost, but need 4 to 34 clock cycles per result. This design gives 18 to
  21 bits, but a new result in every clock cycle.
