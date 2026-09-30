# FPGA
Arithmetic in VHDL for an FPGA. Each folder contains a design, a testbench,
a README.md that describes the design and lists the resource usage and timing,
and an ALGORITHM.md that explains the algorithm in detail: why it works, how
precise it is, and the trade-offs.

| Folder | Description | Latency (32 bits)
| ------ | ----------- | -------
| [`booth`](booth) | Multiplies two signed numbers using Booth's algorithm with radix 4, and a faster carry-save version. | 64 ns (24 ns for the carry-save version)
| [`fast_divide`](fast_divide) | Divides two 32-bit unsigned integers using Goldschmidt division, with about 34 significant bits. | At most 140 ns
| [`srt`](srt) | Divides two 29-bit unsigned integers using SRT division with radix 4, as in the Pentium, including the FDIV bug. | 185 ns
| [`c64_sqrt`](c64_sqrt) | Square root of a C64 floating point number, using the digit-by-digit method. | 139 ns
| [`c64_sqrt2`](c64_sqrt2) | Square root of a C64 floating point number, using Goldschmidt's algorithm with multipliers. | 40 to 119 ns
| [`pipeline_sqrt`](pipeline_sqrt) | Pipelined square root of a 22-bit fixed-point number (format 2.20, with a 22-bit result), using lookup tables and one multiplier, with one result per clock cycle. | 16 ns
| [`c64_sincos`](c64_sincos) | Sine and cosine of a C64 floating point number, using CORDIC. | 237 ns
| [`tan_cordic`](tan_cordic) | Tangent of a fixed-point angle, using the CORDIC variant of the Intel 8087. | 478 ns, with 8 iterations, at 108.7 MHz

The latency is the time from when the input is accepted until the result is
valid, for 32-bit operands, or a 32-bit mantissa for the C64 floating point
numbers. `srt` and `pipeline_sqrt` do not support 32 bits, so their latency is
for the width given in the description. The latency is at the clock frequency
of the timing constraint in the `.xdc` file of each folder, which `make vivado`
verifies. The exception is `tan_cordic`, whose constraint (125 MHz) is for the
default of 24 bits, where the latency is 320 ns. With 32 bits it only meets
108.7 MHz. Some designs can run at a higher clock frequency, see their READMEs.

## Interface
All the designs have the same top-level interface, with the same naming
convention as [`booth`](booth):

| Port | Direction | Description
| ---- | --------- | -----------
| `clk_i` | in | Clock.
| `rst_i` | in | Synchronous reset, active high. Clears `m_valid_o`, and abandons a calculation in progress.
| `s_valid_i`, `s_ready_o` | in, out | Handshake of the input.
| `s_<name>_i` | in | The operands, e.g. `s_a_i` and `s_b_i` in `booth`.
| `m_valid_o`, `m_ready_i` | out, in | Handshake of the output.
| `m_<name>_o` | out | The results, e.g. `m_res_o` in `booth`.

Both the input and the output use an
[AXI](https://en.wikipedia.org/wiki/Advanced_eXtensible_Interface)-style
VALID/READY handshake: a value is transferred in a clock cycle where both valid
and ready are high. The sender keeps valid high and the value unchanged until
then. The operands and results are `std_logic_vector`, and none of the output
signals depend combinatorially on any of the input signals. Each testbench
asserts valid and ready randomly, to verify the handshake.

## Running
Each folder has a Makefile. Type `make` in the folder to list the supported
targets. All folders support:
* `make sim` runs the testbench. This requires [GHDL](https://github.com/ghdl/ghdl).
* `make debug` runs a (shorter) simulation, and writes a waveform. `make show_debug`
  shows it in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make vivado` synthesizes and implements the design with
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html),
  and fails if it does not meet the timing constraint in the `.xdc` file. This
  expects Vivado 2025.1 in `/opt/Xilinx/2025.1/Vivado`.
* `make clean` removes the generated files.

Some folders have more targets, e.g. `make formal` for formal verification with
[SymbiYosys](https://github.com/YosysHQ/sby) (`booth` and `srt`). Most folders
also have a Vivado project (`.xpr`), for use in the Vivado GUI.

Unless stated otherwise, the resource usage and timing in the READMEs are from
Vivado, for the Artix-7 part xc7a200tfbg484-2.

## Coding style
All the VHDL files follow the same coding style, which [`vsg.yml`](vsg.yml)
describes, and which [VSG](https://vhdl-style-guide.readthedocs.io/) (VHDL
Style Guide) checks. To check the files in one folder, type
`vsg -c ../vsg.yml -ap -f *.vhd` in that folder. VSG reports no errors, only
warnings for lines longer than 100 characters.
