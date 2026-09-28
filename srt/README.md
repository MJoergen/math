# SRT
This divides two numbers using the SRT algorithm (with radix 4), in VHDL for
an FPGA. It is inspired by this analysis:
[https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html](https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html)

## The algorithm
SRT division produces the quotient one digit at a time, like long division by
hand. Each iteration does:
```
q := PLA(n, d)      -- select quotient digit
n := 4*(n - q*d)    -- update partial remainder
```
where $d$ is the divisor and $n$ is the partial remainder. With radix 4, each
digit $q$ is one of $\{-2, -1, 0, 1, 2\}$, so the quotient gains two bits per
iteration. The digit is selected by a small lookup table that only looks at the
top bits of $n$ and $d$. This works because the digit only needs to be
approximately right, since a slightly wrong digit is corrected by the later
digits. In the Pentium, missing entries in this table caused the famous FDIV
bug.

[ALGORITHM.md](ALGORITHM.md) explains the algorithm in detail: why it works,
why the table only needs 7 bits of $n$ and 4 bits of $d$, the range of the
partial remainder, and the Pentium bug. It also has a diagram of the table.

## Files
| File             | Description
| ---------------- | -----------
| [`srt_float.vhd`](srt_float.vhd) | Top level. Divides two unsigned integers, returns a 32.32 fixed-point quotient.
| [`normalizer.vhd`](normalizer.vhd) | Shifts dividend and divisor into the range [1, 2).
| [`div.vhd`](div.vhd) | The SRT divider itself. Operates on normalized values.
| [`pla.vhd`](pla.vhd) | The quotient digit selection table.
| [`pla_pentium.vhd`](pla_pentium.vhd) | The Pentium's table, with and without the FDIV bug. Can replace `pla.vhd`.
| [`shifter.vhd`](shifter.vhd) | Shifts the quotient back to undo the normalization.
| [`tb_srt.vhd`](tb_srt.vhd) | Testbench for `srt_float`.
| [`div.psl`](div.psl), [`div.sby`](div.sby) | Formal verification of `div`.
| [`div.gtkw`](div.gtkw) | GTKWave setup for viewing the formal verification traces.
| [`srt.xpr`](srt.xpr), [`srt.xdc`](srt.xdc) | Vivado project (Artix-7 xc7a200tfbg484-2) and timing constraint (200 MHz), for synthesis.
| [`srt.py`](srt.py) | Bit-exact model of `srt_float`, and a checker for the quotient digit table.
| [`pla.tex`](pla.tex), [`pla_steps.tex`](pla_steps.tex), [`pla.svg`](pla.svg) | Diagram of the quotient digit table.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm.

## Interface of `srt_float`
* `n_i`, `d_i`: Unsigned integers. They are valid if both are less than 2^29,
  and `d_i` is not zero.
* `q_o`: The quotient `n_i/d_i`, with 32 integer bits and 32 fractional bits,
  rounded to nearest.
* Pulse `start_over_i` for one clock cycle to start a division. The inputs are
  only sampled in that clock cycle.
* `busy_o` is high while the division is in progress. When it returns low,
  `q_o` is valid. A division takes 37 clock cycles.
* `invalid_o` is set together with `q_o`, if the inputs were invalid. The
  quotient is then all ones (the largest value), and the division only takes 3
  clock cycles.

## Number format
Internally (in `div.vhd` and `pla.vhd`) the values are two's complement with 4
integer bits (including the sign). The inputs to `div` are normalized so the
top nibble is `0001`, i.e. they are in the range [1, 2). The partial remainder
`n` is kept in carry-save form (a sum and a carry, like in the Pentium), so
calculating the next partial remainder needs no carry chain, see `div.vhd`. It
then stays in the range $-4.5 < n < 4.5$, see
[The actual range of the partial remainder](ALGORITHM.md#the-actual-range-of-the-partial-remainder).
The formal verification checks $-4.5 \le n < 4.5$.

## Formal verification
The formal verification (`div.psl`, `div.sby`) checks `div` with `G_SIZE=16`
and with `G_SIZE=32` (as used in `srt_float`), for all normalized inputs,
including a zero dividend:
* The partial remainder stays within its bounds, and never overflows.
* The quotient `q_o` matches the digits chosen by the PLA.
* The quotient is correct: it differs from the exact value n/d by less than
  2/3 of its least significant bit.

SMT solvers are slow at multiplication, so instead of calculating q*d directly,
`div.psl` tracks q*d alongside the divider using only additions, and checks a
few invariants in every clock cycle. See the comments in `div.psl`.

The properties are proven with k-induction, so they hold in every clock cycle,
not just for a bounded number of them. This takes about a minute. The
invariants that are checked in every clock cycle are what makes this possible:
each clock cycle is a small local step for the solver.

## Running
Type `make` to list the supported targets. The most important ones are:
* `make sim` runs the testbench. It checks a number of edge cases (invalid
  inputs, zero dividend, the largest valid inputs, and every normalization
  shift), all divisions n/d with 1 <= n, d <= 100, and 20000 random divisions
  across the whole range of valid inputs. The expected results are calculated
  exactly, including the rounding. This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 30 seconds.
  `make sim PLA=pentium` runs it with the Pentium's original table instead
  (or `PLA=pentium_fixed`). Then the divider has the Pentium's FDIV bug, and
  the testbench verifies that 4195835/3145727 gives the Pentium's wrong
  result.
* `make debug` runs only the first 10 us of the testbench (about 25 divisions),
  and writes a waveform to `srt.ghw`. Use `make show_debug` to view it in
  GTKWave.
* `make formal` runs the formal verification. This requires
  [SymbiYosys](https://github.com/YosysHQ/sby), the GHDL plugin for Yosys, and
  the [Yices 2](https://github.com/SRI-CSL/yices2) solver. It takes about a
  minute.
  If it fails, use `make show_prove` or `make show_induct` to view the
  counterexample in GTKWave, and `make show_cover` to view the cover trace.
* `make model` (or `./srt.py` and `./srt.py --exact`) checks the quotient
  digit table, and tests the model. See below.
* `make clean` removes the generated files.

The CI (`.github/workflows/srt.yml`) runs `make model`, `make sim`, and
`make formal` on every pull request, and every push to master, that changes
this directory.

## The model
`srt.py` is a bit-exact model of `srt_float`, written in Python using
integers. It builds the quotient digit table the same way as `pla.vhd`, and
keeps the partial remainder in carry-save form like `div.vhd`, so it calculates
exactly the same quotient as the VHDL, including when the table is modified.

* `./srt.py` checks every entry of the table: For all values of n and d that
  map to the entry, and that satisfy |n/d| < 8/3, the next partial remainder
  must satisfy this too. With a carry-save partial remainder the table may see
  n one row too low, so this must also hold for the row above the entry. This
  check is slightly conservative: some entries near the edge are never used.
  It then prints the range of the partial remainder, and tests over 100000
  divisions against the exact result. It exits with an error if any of the
  divisions is wrong.
* `./srt.py --exact` does the same with an exact partial remainder, i.e.
  without carry-save. The table in `pla.vhd` passes the check in both cases,
  see [The table](ALGORITHM.md#the-table).
* `./srt.py --bounds` prints the range of the partial remainder for each
  column of the table, see
  [The actual range of the partial remainder](ALGORITHM.md#the-actual-range-of-the-partial-remainder).
* `./srt.py 1 3 --trace` calculates 1/3, and shows the partial remainder, the
  table row it is seen as, and the quotient digit of each iteration.
* `./srt.py --remove 2.5:1.5` removes a table entry (sets it to zero, like the
  missing entries in the Pentium). It shows which entries now fail the check,
  how the range of the partial remainder changes, and tests divisions whose
  divisor uses the failing entries, to find a wrong result. A failing entry
  outside the range of the partial remainder is reported as never used. Use
  `--remove=-2.5:1.0` for a negative n. With `--exact`, it also searches
  backwards from each failing entry for a division that uses it. The search
  works backwards because some table entries may be used by very few
  divisions: in the Pentium, only about one in nine billion random divisions
  reached a missing entry.
* `./srt.py --pla pentium` uses the Pentium's original table from
  `pla_pentium.vhd` instead (`--pla pentium_fixed` for the fixed one). This
  reproduces the FDIV bug: `./srt.py 4195835 3145727 --pla pentium` gives the
  Pentium's wrong result. See
  [The Pentium FDIV bug](ALGORITHM.md#the-pentium-fdiv-bug).

## Links
* [http://degiorgi.math.hr/aaa_sem/Div/925-934.pdf](http://degiorgi.math.hr/aaa_sem/Div/925-934.pdf)
* [https://en.wikipedia.org/wiki/Division_algorithm#SRT_division](https://en.wikipedia.org/wiki/Division_algorithm#SRT_division)
* [https://www.ardent-tool.com/CPU/Intel/fdiv/white11.pdf](https://www.ardent-tool.com/CPU/Intel/fdiv/white11.pdf)
* [https://people.cs.vt.edu/~naren/Courses/CS3414/assignments/pentium.pdf](https://people.cs.vt.edu/~naren/Courses/CS3414/assignments/pentium.pdf)

