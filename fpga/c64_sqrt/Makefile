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

SRC = c64_sqrt.vhd tb_c64_sqrt.vhd

# The values of G_STEPS to test, e.g. "make sim STEPS=4"
STEPS ?= 1 2 4 8 16 32

# The testbench calculates the square root of 0, 1, 2, 3, 4, 0.5, and -1
# (which gives an error), and of 15938 values from 0.031 to 8. It stops at the
# first wrong result. It runs once with random stalls on the input and the
# output for each value of G_STEPS, and then without any stalls with the
# default G_STEPS. Each run prints the average number of clock cycles per
# calculation.
.PHONY: sim
sim: $(SRC) ## Run the testbench, with and without stalls (about 1 minute)
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_c64_sqrt
	set -e; for steps in $(STEPS); do \
	   ghdl -r --std=08 tb_c64_sqrt -gG_STEPS=$$steps --assert-level=error; \
	done
	ghdl -r --std=08 tb_c64_sqrt -gG_VALID_PCT=100 -gG_READY_PCT=100 --assert-level=error

# The same, with random stalls, but also write a waveform (about 26 MB)
.PHONY: debug
debug: $(SRC) ## Run the testbench, and write a waveform to c64_sqrt.ghw
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_c64_sqrt
	ghdl -r --std=08 tb_c64_sqrt --assert-level=error --wave=c64_sqrt.ghw

# GTKWave, see https://github.com/gtkwave/gtkwave
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave c64_sqrt.ghw c64_sqrt.gtkw


#######################
# Synthesis using Vivado
#######################

XILINX_DIR = /opt/Xilinx/2025.1/Vivado

# The generic, e.g. "make vivado VIVADO_STEPS=2"
VIVADO_STEPS ?= 4
VIVADO_SRC    = c64_sqrt.vhd
VIVADO_PART   = xc7a200tfbg484-2
VIVADO_DIR    = vivado/c64_sqrt_$(VIVADO_STEPS)

# Synthesize and implement the design out of context (see vivado.tcl), and
# write the reports timing_summary.rpt and utilization.rpt to $(VIVADO_DIR).
# This fails if the design does not meet the clock constraint in
# c64_sqrt.xdc. The project c64_sqrt.xpr uses the same settings.
#
# -mode batch, NOT -mode tcl. In tcl mode Vivado exits 0 even when the sourced
# script raises an error, so an aborted build would be reported as success to
# make. Batch mode propagates the error as a non-zero exit status. The modes
# are described in UG894, "Vivado Design Suite User Guide: Using Tcl
# Scripting": https://docs.amd.com/r/en-US/ug894-vivado-tcl-scripting
.PHONY: vivado
vivado: $(VIVADO_DIR)/post_route.dcp ## Run synthesis and implementation using Vivado (about 2 minutes)

$(VIVADO_DIR)/post_route.dcp: vivado.tcl $(VIVADO_SRC) c64_sqrt.xdc
	mkdir -p $(VIVADO_DIR)
	cd $(VIVADO_DIR) && bash -c "source $(XILINX_DIR)/settings64.sh ; \
	   vivado -mode batch -nojournal -log vivado.log -source $(CURDIR)/vivado.tcl \
	   -tclargs $(VIVADO_STEPS) $(VIVADO_PART) $(CURDIR)"


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_c64_sqrt c64_sqrt.ghw vivado .Xil
