# Typing just "make" shows the supported targets. Each target is documented
# by a comment starting with "##" on the same line.
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo "Usage: make <target>"
	@echo
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_.-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)


#######################
# Simulation
#######################

# The simulation uses GHDL, see https://github.com/ghdl/ghdl

SRC = booth.vhd booth_radix2.vhd tb_booth.vhd

# The designs to test: 4 (booth.vhd) and 2 (booth_radix2.vhd), see G_RADIX in
# tb_booth.vhd. E.g. "make sim RADIX=2" tests only radix 2.
RADIX ?= 4 2

# For each design, run the testbench with:
# * All pairs of inputs for G_DATA_SIZE from 1 to 7, with random stalls.
# * 5000 random pairs of inputs for G_DATA_SIZE of 16, 17, and 32, with random
#   stalls.
# * No stalls, for G_DATA_SIZE of 9 and 8, which also verifies the throughput.
# * A slow consumer, which is ready in only 10% of the clock cycles.
.PHONY: sim
sim: $(SRC) ## Run the testbench for both designs (about 10 seconds)
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_booth
	set -e; for radix in $(RADIX); do \
	   run="ghdl -r --std=08 tb_booth -gG_RADIX=$$radix --assert-level=error"; \
	   for size in 1 2 3 4 5 6 7; do $$run -gG_DATA_SIZE=$$size; done; \
	   for size in 16 17 32; do $$run -gG_DATA_SIZE=$$size -gG_EXHAUSTIVE=false; done; \
	   $$run -gG_DATA_SIZE=9 -gG_EXHAUSTIVE=false -gG_VALID_PCT=100 -gG_READY_PCT=100; \
	   $$run -gG_DATA_SIZE=8 -gG_EXHAUSTIVE=false -gG_VALID_PCT=100 -gG_READY_PCT=100; \
	   $$run -gG_DATA_SIZE=8 -gG_EXHAUSTIVE=false -gG_VALID_PCT=100 -gG_READY_PCT=10; \
	done
	@echo "All tests passed"

# Run 20 random multiplications with random stalls, and write a waveform
.PHONY: debug
debug: $(SRC) ## Run a short simulation of booth.vhd, and write a waveform to booth.ghw
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_booth
	ghdl -r --std=08 tb_booth -gG_DATA_SIZE=8 -gG_EXHAUSTIVE=false -gG_NUM_TESTS=20 --wave=booth.ghw

# GTKWave, see https://github.com/gtkwave/gtkwave
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave booth.ghw


#######################
# Synthesis
#######################

# Estimate the resource usage of both designs, for the table in ALGORITHM.md.
#
# Each design is synthesized for Xilinx 7-series FPGAs with Yosys (see
# https://github.com/YosysHQ/yosys, command synth_xilinx), using the GHDL plugin
# for Yosys (see https://github.com/ghdl/ghdl-yosys-plugin) to read the VHDL.
# This prints a Markdown table with, for each design:
# * LUT, FF, CARRY4: The number of cells of each type in the whole design.
# * Logic levels: The largest number of LUT and CARRY4 cells on any path
#   between two registers (or between a port and a register), as found by the
#   Yosys command ltp. Only the LUT, MUXF, and CARRY4 cells are selected, so
#   that the paths start and end at the flip-flops.
# The numbers are taken from the last statistics in the log files (synth_xilinx
# prints some too), which are written to the directory synth/.

# The values of G_DATA_SIZE, e.g. "make synth SIZES=16"
SIZES ?= 8 16 32 64

.PHONY: synth
synth: booth.vhd booth_radix2.vhd ## Estimate the resource usage of both designs with Yosys (about 20 seconds)
	@mkdir -p synth
	@echo "| Design | G_DATA_SIZE | LUT | FF | CARRY4 | Logic levels |"
	@echo "| ------ | ----------- | --- | -- | ------ | ------------ |"
	@set -e; for size in $(SIZES); do for top in booth_radix2 booth; do \
	   log=synth/$${top}_$$size.log; \
	   yosys -q -m ghdl -l $$log -p "ghdl --std=08 -gG_DATA_SIZE=$$size $$top.vhd -e $$top; \
	      synth_xilinx -top $$top -flatten; stat; ltp t:LUT* t:MUXF* t:CARRY4 w:*"; \
	   awk -v top=$$top -v size=$$size ' \
	      /Printing statistics/ { lut = ff = c4 = 0 } \
	      $$2 ~ /^LUT[1-6]$$/ { lut += $$1 } \
	      $$2 ~ /^FD/         { ff  += $$1 } \
	      $$2 == "CARRY4"     { c4  += $$1 } \
	      /Longest topological path/ { sub(/.*length=/, ""); sub(/\).*/, ""); levels = $$0 } \
	      END { printf "| %s | %d | %d | %d | %d | %d |\n", top, size, lut, ff, c4, levels }' $$log; \
	done; done


#######################
# Formal verification
#######################

# The properties for booth_radix2.vhd are the same as for booth.vhd, see
# booth.psl. Only the vunit binding is different.
booth_radix2.psl: booth.psl
	sed 's/(booth(synthesis))/(booth_radix2(synthesis))/' $< > $@

# This runs all the tasks defined in booth.sby, using SymbiYosys (see
# https://github.com/YosysHQ/sby). "yosys -m ghdl" loads the GHDL plugin for
# Yosys (see https://github.com/ghdl/ghdl-yosys-plugin), which reads the VHDL
# and PSL files.
.PHONY: formal
formal: booth.sby booth.psl booth_radix2.psl booth.vhd booth_radix2.vhd ## Run the formal verification of both designs (about 1.5 minutes)
	sby --yosys "yosys -m ghdl" -f booth.sby

# The traces are VCD files, which GTKWave can show. $(TASK) is one of the
# tasks in booth.sby.
TASK ?= prove4

.PHONY: show_prove
show_prove: ## Show the counterexample from a failing "make formal" in GTKWave (TASK=prove4)
	gtkwave booth_$(TASK)/engine_0/trace.vcd

.PHONY: show_induct
show_induct: ## Show the trace from a failing induction step in GTKWave (TASK=prove4)
	gtkwave booth_$(TASK)/engine_0/trace_induct.vcd


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_booth booth.ghw synth booth_radix2.psl booth booth_prove4 booth_prove4_odd booth_prove2 booth_cover4 booth_cover2
