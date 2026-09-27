# SRT
This divides two numbers using the SRT algorithm (with radix 4).
It is inspired by this analysis:
[https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html](https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html)

## The algorithm
SRT division produces one quotient digit per iteration. With radix 4, each
digit is two bits, and is chosen from the redundant set {-2, -1, 0, 1, 2}.
Each iteration does:
```
q := PLA(n, d)      -- select quotient digit
n := 4*(n - q*d)    -- update partial remainder
```
Because the digit set is redundant, the digit need not be chosen exactly.
A digit that is slightly off is corrected by the later digits, as long as the
partial remainder stays within |n/d| < 8/3. Therefore the digit can be selected
from a small table that only looks at the top 7 bits of `n` and the top 4
bits (after the leading one) of `d`. In the Pentium this table was
implemented as a PLA, and the famous FDIV bug was caused by five missing
entries in this table.

The positive and negative digits are accumulated separately, and subtracted
only at the end.

## Files
| File             | Description
| ---------------- | -----------
| `srt_float.vhd`  | Top level. Divides two unsigned integers, returns a 32.32 fixed-point quotient.
| `normalizer.vhd` | Shifts dividend and divisor into the range [1, 2).
| `div.vhd`        | The SRT divider itself. Operates on normalized values.
| `pla.vhd`        | The quotient digit selection table.
| `shifter.vhd`    | Shifts the quotient back to undo the normalization.
| `tb_srt.vhd`     | Testbench for `srt_float`.
| `div.psl`, `div.sby` | Formal verification of `div`.
| `div.gtkw`       | GTKWave setup for viewing the formal verification traces.
| `srt.xpr`, `srt.xdc` | Vivado project (Artix-7 xc7a200tfbg484-2) and timing constraint (200 MHz), for synthesis.
| `srt.py`, `srt.cpp` | Floating point reference models of the algorithm.

## Interface of `srt_float`
* `n_i`, `d_i`: Unsigned integers. They must be less than 2^29, and `d_i` must
  be non-zero. In simulation, an assertion reports invalid inputs when a
  division is started.
* `q_o`: The quotient `n_i/d_i`, with 32 integer bits and 32 fractional bits,
  rounded to nearest.
* Pulse `start_over_i` for one clock cycle to start a division. The inputs are
  only sampled in that clock cycle.
* `busy_o` is high while the division is in progress. When it returns low,
  `q_o` is valid. A division takes 37 clock cycles.

## Number format
Internally (in `div.vhd` and `pla.vhd`) the values are two's complement with 4
integer bits (including the sign). The inputs to `div` are normalized so the
top nibble is `0001`, i.e. they are in the range [1, 2). The partial remainder
`n` then stays in the range [-4, 4.25), as shown by the formal verification.

## Formal verification
The formal verification (`div.psl`, `div.sby`) checks `div` with `G_SIZE=16`
for all normalized inputs, including a zero dividend:
* The partial remainder stays within its bounds, and never overflows.
* The quotient `q_o` matches the digits chosen by the PLA.
* The quotient is correct: it differs from the exact value n/d by less than
  2/3 of its least significant bit.

SMT solvers are slow at multiplication, so instead of calculating q*d directly,
`div.psl` tracks q*d alongside the divider using only additions, and checks a
few invariants in every clock cycle. See the comments in `div.psl`.

Bounded model checking is sufficient, because every division starts from a
state that depends only on the inputs, and the depth covers a complete
division.

## Running
* `make sim` (the default) runs the testbench. It checks a number of edge cases
  (zero dividend, the largest inputs, and every normalization shift), and then
  all divisions n/d with 1 <= n, d <= 1000. The expected results are calculated
  exactly, including the rounding. This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 15 minutes.
* `make debug` runs only the first 10 us of the testbench (about 25 divisions),
  and writes a waveform to `srt.ghw`. Use `make show_debug` to view it in
  GTKWave.
* `make formal` runs the formal verification. This requires
  [SymbiYosys](https://github.com/YosysHQ/sby), the GHDL plugin for Yosys, and
  the [Yices 2](https://github.com/SRI-CSL/yices2) solver. The BMC task takes
  about 25 minutes.
  Use `make show_bmc` or `make show_cover` to view the traces in GTKWave.
* `make srt` builds the C++ reference model. `./srt.py` runs the Python model.
* `make clean` removes the generated files.

## Links
* [http://degiorgi.math.hr/aaa_sem/Div/925-934.pdf](http://degiorgi.math.hr/aaa_sem/Div/925-934.pdf)
* [https://en.wikipedia.org/wiki/Division_algorithm#SRT_division](https://en.wikipedia.org/wiki/Division_algorithm#SRT_division)
* [https://www.ardent-tool.com/CPU/Intel/fdiv/white11.pdf](https://www.ardent-tool.com/CPU/Intel/fdiv/white11.pdf)
* [https://people.cs.vt.edu/~naren/Courses/CS3414/assignments/pentium.pdf](https://people.cs.vt.edu/~naren/Courses/CS3414/assignments/pentium.pdf)

