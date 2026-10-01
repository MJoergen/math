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

SRC = c64_sincos_pkg.vhd c64_sincos.vhd tb_c64_sincos.vhd

# The values of G_STEPS to test, e.g. "make sim STEPS=4"
STEPS ?= 1 2 4 8 16 32

# The testbench calculates the sine and cosine of 121 angles from 0 to pi/4,
# checks that the absolute error is less than 2^(-31), and prints the largest
# absolute error of each. It runs once with random stalls on the input and the
# output for each value of G_STEPS, and then without any stalls with the
# default G_STEPS. Each run prints the average number of clock cycles per
# calculation.
.PHONY: sim
sim: $(SRC) ## Run the testbench, with and without stalls (about 1 second)
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_c64_sincos
	set -e; for steps in $(STEPS); do \
	   ghdl -r --std=08 tb_c64_sincos -gG_STEPS=$$steps --assert-level=error; \
	done
	ghdl -r --std=08 tb_c64_sincos -gG_VALID_PCT=100 -gG_READY_PCT=100 --assert-level=error

# The same, with random stalls, but also write a waveform (about 1 MB)
.PHONY: debug
debug: $(SRC) ## Run the testbench, and write a waveform to c64_sincos.ghw
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_c64_sincos
	ghdl -r --std=08 tb_c64_sincos --assert-level=error --wave=c64_sincos.ghw

# GTKWave, see https://github.com/gtkwave/gtkwave
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave c64_sincos.ghw c64_sincos.gtkw


#######################
# Synthesis using Vivado
#######################

XILINX_DIR = /opt/Xilinx/2025.1/Vivado

# The generic, e.g. "make vivado VIVADO_STEPS=2"
VIVADO_STEPS ?= 4
VIVADO_SRC    = c64_sincos_pkg.vhd c64_sincos.vhd
VIVADO_PART   = xc7a200tfbg484-2
VIVADO_DIR    = vivado/c64_sincos_$(VIVADO_STEPS)

# Synthesize and implement the design out of context (see vivado.tcl), and
# write the reports timing_summary.rpt and utilization.rpt to $(VIVADO_DIR).
# This fails if the design does not meet the clock constraint in
# c64_sincos.xdc. The project c64_sincos.xpr uses the same settings.
#
# -mode batch, NOT -mode tcl. In tcl mode Vivado exits 0 even when the sourced
# script raises an error, so an aborted build would be reported as success to
# make. Batch mode propagates the error as a non-zero exit status. The modes
# are described in UG894, "Vivado Design Suite User Guide: Using Tcl
# Scripting": https://docs.amd.com/r/en-US/ug894-vivado-tcl-scripting
.PHONY: vivado
vivado: $(VIVADO_DIR)/post_route.dcp ## Run synthesis and implementation using Vivado (about 2.5 minutes)

$(VIVADO_DIR)/post_route.dcp: vivado.tcl $(VIVADO_SRC) c64_sincos.xdc
	mkdir -p $(VIVADO_DIR)
	cd $(VIVADO_DIR) && bash -c "source $(XILINX_DIR)/settings64.sh ; \
	   vivado -mode batch -nojournal -log vivado.log -source $(CURDIR)/vivado.tcl \
	   -tclargs $(VIVADO_STEPS) $(VIVADO_PART) $(CURDIR)"


#######################
# Formal verification
#######################

# The tasks in c64_sincos.sby. SymbiYosys writes the results of each task to a
# directory c64_sincos_<task>.
FORMAL_TASKS = prove1 prove4 cover4

# This runs all the tasks defined in c64_sincos.sby, using SymbiYosys (see
# https://github.com/YosysHQ/sby). "yosys -m ghdl" loads the GHDL plugin for
# Yosys (see https://github.com/ghdl/ghdl-yosys-plugin), which reads the VHDL
# and PSL files.
.PHONY: formal
formal: c64_sincos.sby c64_sincos.psl c64_sincos_pkg.vhd c64_sincos.vhd ## Run the formal verification (about 40 seconds)
	sby --yosys "yosys -m ghdl" -f c64_sincos.sby

# The traces are VCD files, which GTKWave can show. $(TASK) is one of the
# tasks in c64_sincos.sby.
TASK ?= prove4

.PHONY: show_prove
show_prove: ## Show the counterexample from a failing "make formal" in GTKWave (TASK=prove4)
	gtkwave c64_sincos_$(TASK)/engine_0/trace.vcd

.PHONY: show_induct
show_induct: ## Show the trace from a failing induction step in GTKWave (TASK=prove4)
	gtkwave c64_sincos_$(TASK)/engine_0/trace_induct.vcd


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_c64_sincos c64_sincos.ghw vivado .Xil
	rm -rf $(addprefix c64_sincos_,$(FORMAL_TASKS)) c64_sincos
