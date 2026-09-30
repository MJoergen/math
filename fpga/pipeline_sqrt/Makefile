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

SRC = pipeline_sqrt.vhd tb_pipeline_sqrt.vhd

# The values of G_EXTRA_BITS to test, e.g. "make sim EXTRA_BITS=2"
EXTRA_BITS ?= 0 1 2 3 4

# For each value of G_EXTRA_BITS, the testbench calculates the square root of
# all 3*2^20 valid inputs, from 0x100000 to 0x3FFFFF, without stalls, and
# prints each result whose error is larger than any previous error. It also
# verifies that there is a result in every clock cycle. Finally, it runs with
# G_EXTRA_BITS=2 and random stalls on the input and the output, for 100000
# inputs in a scrambled order (G_STRIDE, see tb_pipeline_sqrt.vhd).
.PHONY: sim
sim: $(SRC) ## Run the testbench for G_EXTRA_BITS from 0 to 4 (about 3 to 4 minutes each), and with stalls
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_pipeline_sqrt
	set -e; for bits in $(EXTRA_BITS); do \
	   echo "G_EXTRA_BITS=$$bits"; \
	   ghdl -r --std=08 tb_pipeline_sqrt -gG_EXTRA_BITS=$$bits --assert-level=error; \
	done
	echo "G_EXTRA_BITS=2, with stalls"
	ghdl -r --std=08 tb_pipeline_sqrt -gG_EXTRA_BITS=2 -gG_NUM_TESTS=100000 -gG_STRIDE=40507 \
	   -gG_VALID_PCT=70 -gG_READY_PCT=70 --assert-level=error

# A short run with random stalls, which writes about 35 us of waveform
.PHONY: debug
debug: $(SRC) ## Run the testbench shortly with G_EXTRA_BITS=2 and stalls, and write a waveform to pipeline_sqrt.ghw
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_pipeline_sqrt
	ghdl -r --std=08 tb_pipeline_sqrt -gG_EXTRA_BITS=2 -gG_NUM_TESTS=2000 -gG_STRIDE=40507 \
	   -gG_VALID_PCT=70 -gG_READY_PCT=70 --assert-level=error --wave=pipeline_sqrt.ghw

# GTKWave, see https://github.com/gtkwave/gtkwave
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave pipeline_sqrt.ghw pipeline_sqrt.gtkw


#######################
# Synthesis using Vivado
#######################

XILINX_DIR = /opt/Xilinx/2025.1/Vivado

# The value of G_EXTRA_BITS, e.g. "make vivado VIVADO_EXTRA_BITS=4"
VIVADO_EXTRA_BITS ?= 2
VIVADO_SRC         = pipeline_sqrt.vhd
VIVADO_PART        = xc7a200tfbg484-2
VIVADO_DIR         = vivado/pipeline_sqrt_$(VIVADO_EXTRA_BITS)

# Synthesize and implement the design out of context (see vivado.tcl), and
# write the reports timing_summary.rpt and utilization.rpt to $(VIVADO_DIR).
# This fails if the design does not meet the clock constraint in
# pipeline_sqrt.xdc. The project pipeline_sqrt.xpr uses the same settings.
#
# -mode batch, NOT -mode tcl. In tcl mode Vivado exits 0 even when the sourced
# script raises an error, so an aborted build would be reported as success to
# make. Batch mode propagates the error as a non-zero exit status. The modes
# are described in UG894, "Vivado Design Suite User Guide: Using Tcl
# Scripting": https://docs.amd.com/r/en-US/ug894-vivado-tcl-scripting
.PHONY: vivado
vivado: $(VIVADO_DIR)/post_route.dcp ## Run synthesis and implementation using Vivado (about 2 minutes)

$(VIVADO_DIR)/post_route.dcp: vivado.tcl $(VIVADO_SRC) pipeline_sqrt.xdc
	mkdir -p $(VIVADO_DIR)
	cd $(VIVADO_DIR) && bash -c "source $(XILINX_DIR)/settings64.sh ; \
	   vivado -mode batch -nojournal -log vivado.log -source $(CURDIR)/vivado.tcl \
	   -tclargs $(VIVADO_EXTRA_BITS) $(VIVADO_PART) $(CURDIR)"


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_pipeline_sqrt pipeline_sqrt.ghw vivado .Xil
