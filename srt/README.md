# SRT
This divides two numbers using the
[SRT algorithm](https://en.wikipedia.org/wiki/Division_algorithm#SRT_division)
(with radix 4), in VHDL for an FPGA. It is inspired by Ken Shirriff's article
[Intel's \$475 million error: the silicon behind the Pentium division bug](https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html),
which analyses the Pentium's divider from a photo of the die.

## The algorithm
SRT division produces the quotient one digit at a time, like long division by
hand. Each iteration does:
```
q := PLA(n, d)      -- select quotient digit
n := 4*(n - q*d)    -- update partial remainder
```
where $d$ is the divisor and $n$ is the partial remainder. The algorithm uses
radix 4, so the quotient gains one base-4 digit, i.e. two bits, per iteration.
Instead of the ordinary base-4 digits $\lbrace 0, 1, 2, 3 \rbrace$, each
quotient digit $q$ is one of $\lbrace -2, -1, 0, 1, 2 \rbrace$, see
[Radix 4 and the redundant digits](ALGORITHM.md#radix-4-and-the-redundant-digits).
The digit is selected by a small lookup table that only looks at the
top bits of $n$ and $d$. This works because the digit only needs to be
approximately right, since a slightly wrong digit is corrected by the later
digits. D. E. Atkins analysed this in
[Higher-Radix Division Using Estimates of the Divisor and Partial Remainders](http://degiorgi.math.hr/aaa_sem/Div/925-934.pdf)
(IEEE Transactions on Computers, 1968).

In the Pentium this table was a
[PLA](https://en.wikipedia.org/wiki/Programmable_logic_array) (programmable
logic array), so it is called the PLA here too. Missing entries in it caused
the famous [FDIV bug](https://en.wikipedia.org/wiki/Pentium_FDIV_bug). The
story of how the bug was found is told in
[Computational Aspects of the Pentium Affair](https://people.cs.vt.edu/~naren/Courses/CS3414/assignments/pentium.pdf)
by Coe, Mathisen, Moler, and Pratt (IEEE Computational Science and
Engineering, 1995).

[ALGORITHM.md](ALGORITHM.md) explains the algorithm in detail: why it works,
why the table only needs 7 bits of $n$ and 4 bits of $d$, the range of the
partial remainder, and the Pentium bug. It also has a diagram of the table.

## Files
| File             | Description
| ---------------- | -----------
| [`srt.vhd`](srt.vhd) | Top level. Divides two unsigned integers, returns a 32.32 fixed-point quotient.
| [`normalizer.vhd`](normalizer.vhd) | Shifts dividend and divisor into the range [1, 2).
| [`srt_core.vhd`](srt_core.vhd) | The SRT divider itself. Operates on normalized values.
| [`pla.vhd`](pla.vhd) | The quotient digit selection table, implemented as comparisons against thresholds.
| [`pla_pentium.vhd`](pla_pentium.vhd) | The Pentium's table, with and without the FDIV bug. Can replace `pla.vhd`.
| [`shifter.vhd`](shifter.vhd) | Shifts the quotient back to undo the normalization.
| [`tb_srt.vhd`](tb_srt.vhd) | Testbench for `srt`.
| [`srt_core.psl`](srt_core.psl), [`srt_core.sby`](srt_core.sby) | Formal verification of `srt_core`.
| [`srt_core.gtkw`](srt_core.gtkw) | GTKWave setup for viewing the formal verification traces.
| [`srt.gtkw`](srt.gtkw) | [GTKWave](https://github.com/gtkwave/gtkwave) setup for viewing the waveform from `make debug`.
| [`srt.xpr`](srt.xpr) | [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html) project (Artix-7 xc7a200tfbg484-2), for use in the Vivado GUI. `make vivado` does not use it.
| [`srt.xdc`](srt.xdc) | Timing constraint (200 MHz), for synthesis.
| [`srt.py`](srt.py) | Bit-exact model of `srt`, and a checker for the quotient digit table.
| [`pla.tex`](pla.tex), [`pla_steps.tex`](pla_steps.tex), [`pla.svg`](pla.svg) | Diagram of the quotient digit table.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm.

## Interface of `srt`
Both the input and the output use
[AXI](https://en.wikipedia.org/wiki/Advanced_eXtensible_Interface)-style
handshaking: a value is
transferred in a clock cycle where both valid and ready are high. The sender
keeps valid high and the value unchanged until then.

| Port | Direction | Description
| ---- | --------- | -----------
| `s_valid_i`, `s_ready_o` | in, out | Handshake of the input.
| `s_n_i`, `s_d_i` | in | The dividend and divisor, unsigned integers. Both must be less than 2^29, and `s_d_i` must not be zero.
| `m_valid_o`, `m_ready_i` | out, in | Handshake of the output.
| `m_q_o` | out | The quotient `s_n_i/s_d_i`, with 32 integer bits and 32 fractional bits, rounded to nearest.
| `m_invalid_o` | out | Set if the inputs were out of range (see above). The quotient is then all ones (the largest value).

The result is valid 37 clock cycles after the input is transferred (2 clock
cycles for inputs out of range), unless the previous result is still waiting
on the output. The next division can start while the result is waiting on the
output, so with `m_ready_i` high, a division can start every 37 clock cycles.

`srt_core` has the same handshake, with the ports `s_n_i`, `s_d_i`, and
`m_q_o`. It only accepts a new input once its result has been taken.

## Number format
Internally (in `srt_core.vhd` and `pla.vhd`) the values are
[two's complement](https://en.wikipedia.org/wiki/Two%27s_complement)
[fixed point](https://en.wikipedia.org/wiki/Fixed-point_arithmetic) with 4
integer bits (including the sign). The inputs to `srt_core` are
normalized so the top nibble is `0001`, i.e. they are in the range [1, 2).

The partial remainder `n` is kept in
[carry-save](https://en.wikipedia.org/wiki/Carry-save_adder) form (a sum and a
carry, like in the Pentium), so calculating the next partial remainder needs
no carry chain, see
[The carry-save partial remainder](ALGORITHM.md#the-carry-save-partial-remainder).

The partial remainder stays in the range $-4.5 < n < 4.5$, see
[The actual range of the partial remainder](ALGORITHM.md#the-actual-range-of-the-partial-remainder).
The formal verification checks the slightly weaker $-4.5 \le n < 4.5$, since
it only looks at the top 12 bits of `n`, i.e. `n` rounded down to a multiple
of 1/256.

## Formal verification
The formal verification (`srt_core.psl`, `srt_core.sby`) checks `srt_core`
with `G_SIZE=16` and with `G_SIZE=32` (as used in `srt`), for all normalized
inputs, including a zero dividend:
* The partial remainder stays within its bounds, and never overflows.
* The quotient `m_q_o` matches the digits chosen by the PLA.
* The quotient is correct: it differs from the exact value n/d by less than
  2/3 of its least significant bit.
* The result stays valid and unchanged until it is taken.

[SMT solvers](https://en.wikipedia.org/wiki/Satisfiability_modulo_theories)
are slow at multiplication, so instead of calculating q*d directly,
`srt_core.psl` tracks q*d alongside the divider using only additions, and
checks a few invariants in every clock cycle. See the comments in
`srt_core.psl`.

The properties are proven with k-induction, so they hold in every clock cycle,
not just for a bounded number of them. This takes about two minutes. The
invariants that are checked in every clock cycle are what makes this possible:
each clock cycle is a small local step for the solver.

## Running
Type `make` to list the supported targets. The most important ones are:
* `make sim` runs the testbench (see [below](#the-testbench)). This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about a minute.
  `make sim PLA=pentium` runs it with the Pentium's original table instead
  (or `PLA=pentium_fixed`). Then the divider has the Pentium's FDIV bug, and
  the testbench verifies that 4195835/3145727 gives the Pentium's wrong
  result.
* `make debug` runs only the first 10 us of the testbench (about 25 divisions),
  and writes a waveform to `srt.ghw`. Use `make show_debug` to view it in
  GTKWave.
* `make formal` runs the formal verification. This requires
  [SymbiYosys](https://github.com/YosysHQ/sby), the
  [GHDL plugin](https://github.com/ghdl/ghdl-yosys-plugin) for
  [Yosys](https://github.com/YosysHQ/yosys), and
  the [Yices 2](https://github.com/SRI-CSL/yices2) solver. It takes about two
  minutes.
  If it fails, use `make show_prove` or `make show_induct` to view the
  counterexample in GTKWave, and `make show_cover` to view the cover trace.
* `make model` (or `./srt.py` and `./srt.py --exact`) checks the quotient
  digit table, and tests the model. See below.
* `make vivado` runs synthesis and implementation in Vivado, and fails if the
  design does not meet the 200 MHz timing constraint. The timing report is
  written to `timing_summary.rpt`. No I/O pins are assigned, so the bitstream
  is not meant to be loaded into a board.
* `make clean` removes the generated files.

The CI (`.github/workflows/srt.yml`) runs `make model`, `make sim`, and
`make formal` on every pull request, and every push to master, that changes
this directory.

## The testbench
`tb_srt.vhd` checks:
* A number of edge cases: inputs out of range, a zero dividend, the largest
  inputs in range, and every normalization shift.
* All divisions n/d with 1 <= n <= 100 and 1 <= d <= 100.
* 20000 random divisions across the whole range of inputs. These have random
  gaps between the inputs and random backpressure on the output, and the
  testbench checks that the output does not change until it is taken.

The expected results are calculated exactly, including the rounding.

## The model
`srt.py` is a bit-exact model of `srt`, written in Python using integers. It
builds the quotient digit table the same way as `pla.vhd`, and keeps the
partial remainder in carry-save form like `srt_core.vhd`, so it calculates
exactly the same quotient as the VHDL, including when the table is modified.

* `./srt.py` checks every entry of the table: For all values of n and d that
  map to the entry, and that satisfy |n/d| < 8/3, the next partial remainder
  must satisfy this too. With a carry-save partial remainder the table may see
  n one row too low, so this must also hold for the row above the entry. This
  check is slightly conservative: it may flag entries near the edge that are
  never used. It then prints the range of the partial remainder, and tests
  over 100000 divisions against the exact result. It exits with an error if
  any of the divisions is wrong.
* `./srt.py --exact` does the same with an exact partial remainder, i.e.
  without carry-save. The table in `pla.vhd` passes the check in both cases,
  see [The table](ALGORITHM.md#the-table).
* `./srt.py --bounds` prints the range of the partial remainder for each
  column of the table, see
  [The actual range of the partial remainder](ALGORITHM.md#the-actual-range-of-the-partial-remainder).
* `./srt.py 1 3 --trace` calculates 1/3, and shows the partial remainder, the
  table row it is seen as, and the quotient digit of each iteration.
* `./srt.py --remove 2.5:1.5` removes the table entry for n = 2.5 and d = 1.5
  (sets it to zero, like the missing entries in the Pentium). Use
  `--remove=-2.5:1.0` for a negative n. It then shows:
  * which entries now fail the check, and how the range of the partial
    remainder changes. A failing entry outside the range of the partial
    remainder is reported as never used.
  * the result of testing divisions whose divisor is in the column of a
    failing entry, to find a wrong result.
  * with `--exact`: a division that uses each failing entry. It searches
    backwards from the entry, because some entries are used by very few
    divisions: in the Pentium, only about one in nine billion random
    divisions reached a missing entry, according to Intel's
    [Statistical Analysis of Floating Point Flaw in the Pentium Processor](https://www.ardent-tool.com/CPU/Intel/fdiv/white11.pdf)
    (1994).
* `./srt.py --pla pentium` uses the Pentium's original table from
  `pla_pentium.vhd` instead (`--pla pentium_fixed` for the fixed one). This
  reproduces the FDIV bug: `./srt.py 4195835 3145727 --pla pentium` gives the
  Pentium's wrong result. See
  [The Pentium FDIV bug](ALGORITHM.md#the-pentium-fdiv-bug).
