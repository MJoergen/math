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

SRC = fast_sincos_pkg.vhd fast_sincos.vhd tb_fast_sincos.vhd

# The testbench calculates the sine and cosine of 121 angles from 0 to pi/4,
# and prints the average number of clock cycles per calculation and the
# largest absolute error of each. It does not check the results against a
# limit.
.PHONY: sim
sim: $(SRC) ## Run the testbench (about 1 second)
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_fast_sincos
	ghdl -r --std=08 tb_fast_sincos --stop-time=6000us

# The same, but also write a waveform (about 1 MB)
.PHONY: debug
debug: $(SRC) ## Run the testbench, and write a waveform to fast_sincos.ghw
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_fast_sincos
	ghdl -r --std=08 tb_fast_sincos --stop-time=6000us --wave=fast_sincos.ghw

# GTKWave, see https://github.com/gtkwave/gtkwave
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave fast_sincos.ghw fast_sincos.gtkw


#######################
# Synthesis using Vivado
#######################

XILINX_DIR = /opt/Xilinx/2025.1/Vivado

VIVADO_SRC  = fast_sincos_pkg.vhd fast_sincos.vhd
VIVADO_PART = xc7a200tfbg484-2
VIVADO_DIR  = vivado

# Synthesize and implement the design out of context (see vivado.tcl), and
# write the reports timing_summary.rpt and utilization.rpt to $(VIVADO_DIR).
# This fails if the design does not meet the clock constraint in
# fast_sincos.xdc. The project fast_sincos.xpr uses the same settings.
#
# -mode batch, NOT -mode tcl. In tcl mode Vivado exits 0 even when the sourced
# script raises an error, so an aborted build would be reported as success to
# make. Batch mode propagates the error as a non-zero exit status. The modes
# are described in UG894, "Vivado Design Suite User Guide: Using Tcl
# Scripting": https://docs.amd.com/r/en-US/ug894-vivado-tcl-scripting
.PHONY: vivado
vivado: $(VIVADO_DIR)/post_route.dcp ## Run synthesis and implementation using Vivado (about 2.5 minutes)

$(VIVADO_DIR)/post_route.dcp: vivado.tcl $(VIVADO_SRC) fast_sincos.xdc
	mkdir -p $(VIVADO_DIR)
	cd $(VIVADO_DIR) && bash -c "source $(XILINX_DIR)/settings64.sh ; \
	   vivado -mode batch -nojournal -log vivado.log -source $(CURDIR)/vivado.tcl \
	   -tclargs $(VIVADO_PART) $(CURDIR)"


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_fast_sincos fast_sincos.ghw vivado .Xil
