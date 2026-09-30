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

SRC = tan_cordic.vhd tb_tan_cordic.vhd

# The values of G_ITERATIONS and G_FRAC_BITS to sweep, e.g.
# "make sim ITERATIONS=16 FRAC_BITS=24"
ITERATIONS ?= 4 8 12 16 20
FRAC_BITS  ?= 8 16 20 24 28

# Run the testbench with:
# * 150 random angles for each combination of G_ITERATIONS and G_FRAC_BITS,
#   with random stalls.
# * 500 random angles without stalls, and with a slow consumer or a slow
#   producer, which is ready (or valid) in only 10% of the clock cycles.
# * 5000 random angles with the default G_ITERATIONS=16 and G_FRAC_BITS=24,
#   with random stalls.
.PHONY: sim
sim: $(SRC) ## Run the testbench for all the configurations (about 10 seconds)
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_tan_cordic
	set -e; for iterations in $(ITERATIONS); do for frac_bits in $(FRAC_BITS); do \
	   ghdl -r --std=08 tb_tan_cordic -gG_ITERATIONS=$$iterations -gG_FRAC_BITS=$$frac_bits \
	      -gG_NUM_TESTS=150 --assert-level=error; \
	done; done
	ghdl -r --std=08 tb_tan_cordic -gG_NUM_TESTS=500 -gG_VALID_PCT=100 -gG_READY_PCT=100 --assert-level=error
	ghdl -r --std=08 tb_tan_cordic -gG_NUM_TESTS=500 -gG_VALID_PCT=100 -gG_READY_PCT=10  --assert-level=error
	ghdl -r --std=08 tb_tan_cordic -gG_NUM_TESTS=500 -gG_VALID_PCT=10  -gG_READY_PCT=100 --assert-level=error
	ghdl -r --std=08 tb_tan_cordic -gG_NUM_TESTS=5000 --assert-level=error
	@echo "All tests passed"

# Calculate 20 random tangents with random stalls, and write a waveform
.PHONY: debug
debug: $(SRC) ## Run a short simulation, and write a waveform to tan_cordic.ghw
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_tan_cordic
	ghdl -r --std=08 tb_tan_cordic -gG_NUM_TESTS=20 --assert-level=error --wave=tan_cordic.ghw

# GTKWave, see https://github.com/gtkwave/gtkwave. tan_cordic.gtkw selects the
# signals of tb_tan_cordic and the most relevant internal signals of
# tan_cordic.
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave tan_cordic.ghw tan_cordic.gtkw


#######################
# Synthesis using Vivado
#######################

XILINX_DIR = /opt/Xilinx/2025.1/Vivado

# The generics, e.g. "make vivado VIVADO_ITERATIONS=8 VIVADO_FRAC_BITS=16"
VIVADO_ITERATIONS ?= 16
VIVADO_FRAC_BITS  ?= 24
VIVADO_PART        = xc7a200tfbg484-2
VIVADO_DIR         = vivado/tan_cordic_$(VIVADO_ITERATIONS)_$(VIVADO_FRAC_BITS)

# Synthesize and implement the design out of context (see vivado.tcl), and
# write the reports timing_summary.rpt and utilization.rpt to $(VIVADO_DIR).
# This fails if the design does not meet the clock constraint in
# tan_cordic.xdc.
#
# -mode batch, NOT -mode tcl. In tcl mode Vivado exits 0 even when the sourced
# script raises an error, so an aborted build would be reported as success to
# make. Batch mode propagates the error as a non-zero exit status. The modes
# are described in UG894, "Vivado Design Suite User Guide: Using Tcl
# Scripting": https://docs.amd.com/r/en-US/ug894-vivado-tcl-scripting
.PHONY: vivado
vivado: $(VIVADO_DIR)/post_route.dcp ## Run synthesis and implementation using Vivado (about 2 minutes)

$(VIVADO_DIR)/post_route.dcp: vivado.tcl tan_cordic.vhd tan_cordic.xdc
	mkdir -p $(VIVADO_DIR)
	cd $(VIVADO_DIR) && bash -c "source $(XILINX_DIR)/settings64.sh ; \
	   vivado -mode batch -nojournal -log vivado.log -source $(CURDIR)/vivado.tcl \
	   -tclargs $(VIVADO_ITERATIONS) $(VIVADO_FRAC_BITS) $(VIVADO_PART) $(CURDIR)"


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_tan_cordic tan_cordic.ghw vivado .Xil
