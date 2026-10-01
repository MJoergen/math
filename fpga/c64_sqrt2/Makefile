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

SRC = dsp.vhd c64_sqrt2.vhd tb_c64_sqrt2.vhd

# The testbench calculates the square root of 0, 1, 2, 3, 4, 0.5, and -1
# (which gives an error), and of 15938 values from 0.031 to 8. The last bit of
# the mantissa is not always exact, see README.md, so these mismatches are
# reported as warnings, but they do not stop the simulation. It runs twice:
# First with random stalls on the input and the output, and then without any
# stalls. Each run prints the average number of clock cycles per calculation.
.PHONY: sim
sim: $(SRC) ## Run the testbench, with and without stalls (about 40 seconds)
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_c64_sqrt2
	ghdl -r --std=08 tb_c64_sqrt2 --assert-level=error
	ghdl -r --std=08 tb_c64_sqrt2 -gG_VALID_PCT=100 -gG_READY_PCT=100 --assert-level=error

# The same, with random stalls, but also write a waveform (about 33 MB)
.PHONY: debug
debug: $(SRC) ## Run the testbench, and write a waveform to c64_sqrt2.ghw
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_c64_sqrt2
	ghdl -r --std=08 tb_c64_sqrt2 --assert-level=error --wave=c64_sqrt2.ghw

# GTKWave, see https://github.com/gtkwave/gtkwave
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave c64_sqrt2.ghw c64_sqrt2.gtkw


#######################
# Synthesis using Vivado
#######################

XILINX_DIR = /opt/Xilinx/2025.1/Vivado

VIVADO_SRC  = dsp.vhd c64_sqrt2.vhd
VIVADO_PART = xc7a200tfbg484-2
VIVADO_DIR  = vivado

# Synthesize and implement the design out of context (see vivado.tcl), and
# write the reports timing_summary.rpt and utilization.rpt to $(VIVADO_DIR).
# This fails if the design does not meet the clock constraint in
# c64_sqrt2.xdc. The project c64_sqrt2.xpr uses the same settings.
#
# -mode batch, NOT -mode tcl. In tcl mode Vivado exits 0 even when the sourced
# script raises an error, so an aborted build would be reported as success to
# make. Batch mode propagates the error as a non-zero exit status. The modes
# are described in UG894, "Vivado Design Suite User Guide: Using Tcl
# Scripting": https://docs.amd.com/r/en-US/ug894-vivado-tcl-scripting
.PHONY: vivado
vivado: $(VIVADO_DIR)/post_route.dcp ## Run synthesis and implementation using Vivado (about 2 minutes)

$(VIVADO_DIR)/post_route.dcp: vivado.tcl $(VIVADO_SRC) c64_sqrt2.xdc
	mkdir -p $(VIVADO_DIR)
	cd $(VIVADO_DIR) && bash -c "source $(XILINX_DIR)/settings64.sh ; \
	   vivado -mode batch -nojournal -log vivado.log -source $(CURDIR)/vivado.tcl \
	   -tclargs $(VIVADO_PART) $(CURDIR)"


#######################
# Formal verification
#######################

# The tasks in c64_sqrt2.sby. SymbiYosys writes the results of each task to a
# directory c64_sqrt2_<task>.
FORMAL_TASKS = prove cover

# This runs all the tasks defined in c64_sqrt2.sby, using SymbiYosys (see
# https://github.com/YosysHQ/sby). "yosys -m ghdl" loads the GHDL plugin for
# Yosys (see https://github.com/ghdl/ghdl-yosys-plugin), which reads the VHDL
# and PSL files.
.PHONY: formal
formal: c64_sqrt2.sby c64_sqrt2.psl dsp.vhd c64_sqrt2.vhd ## Run the formal verification (a few seconds)
	sby --yosys "yosys -m ghdl" -f c64_sqrt2.sby

# The traces are VCD files, which GTKWave can show. $(TASK) is one of the
# tasks in c64_sqrt2.sby.
TASK ?= prove

.PHONY: show_prove
show_prove: ## Show the counterexample from a failing "make formal" in GTKWave (TASK=prove)
	gtkwave c64_sqrt2_$(TASK)/engine_0/trace.vcd

.PHONY: show_induct
show_induct: ## Show the trace from a failing induction step in GTKWave (TASK=prove)
	gtkwave c64_sqrt2_$(TASK)/engine_0/trace_induct.vcd


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_c64_sqrt2 c64_sqrt2.ghw vivado .Xil
	rm -rf $(addprefix c64_sqrt2_,$(FORMAL_TASKS))
