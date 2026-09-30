# FPGA
Arithmetic in VHDL for an FPGA. Each folder contains a design, a testbench,
and a README.md that explains the algorithm and lists the resource usage and
timing.

| Folder | Description
| ------ | -----------
| [`booth`](booth) | Multiplies two signed numbers using Booth's algorithm with radix 4, and a faster carry-save version.
| [`fast_divide`](fast_divide) | Divides two 32-bit unsigned integers using Goldschmidt division, in at most 7 clock cycles.
| [`srt`](srt) | Divides two unsigned integers using SRT division with radix 4, as in the Pentium, including the FDIV bug.
| [`fast_sqrt`](fast_sqrt) | Square root of a C64 floating point number, using the digit-by-digit method, in 33 clock cycles.
| [`fast_sqrt2`](fast_sqrt2) | Square root of a C64 floating point number, using Goldschmidt's algorithm with multipliers, in 5 to 9 clock cycles.
| [`pipeline_sqrt`](pipeline_sqrt) | Pipelined square root of a fixed-point number, using lookup tables and one multiplier, with one result per clock cycle.
| [`fast_sincos`](fast_sincos) | Sine and cosine of a C64 floating point number, using CORDIC, in 32 clock cycles.
| [`tan_cordic`](tan_cordic) | Tangent of a fixed-point angle, using the CORDIC variant of the Intel 8087.

## Running
Each folder has a Makefile. Type `make` in the folder to list the supported
targets. All folders support:
* `make sim` runs the testbench. This requires [GHDL](https://github.com/ghdl/ghdl).
* `make debug` runs a (shorter) simulation, and writes a waveform. `make show_debug`
  shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make clean` removes the generated files.

Some folders have more targets, e.g. `make formal` for formal verification with
[SymbiYosys](https://github.com/YosysHQ/sby) (`booth` and `srt`), and `make vivado`
for synthesis with Vivado (`booth`, `srt`, and `tan_cordic`). The other folders
have a Vivado project (`.xpr`) instead.

Unless stated otherwise, the resource usage and timing in the READMEs are from
Vivado, for the Artix-7 part xc7a200tfbg484-2.
