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
# For the command line options, see
# https://ghdl.github.io/ghdl/using/InvokingGHDL.html

SIM_SRC = srt.vhd pla.vhd pla_pentium.vhd normalizer.vhd srt_core.vhd shifter.vhd tb_srt.vhd

# The quotient digit table used by the testbench: srt (pla.vhd), pentium (the
# original Pentium table with the FDIV bug), or pentium_fixed. See
# srt_core.vhd.
PLA ?= srt

# Run the complete testbench. No waveform is written, since a waveform of the
# complete run is several GB, and makes GHDL crash.
.PHONY: sim
sim: $(SIM_SRC) ## Run the complete testbench (about a minute). PLA=pentium uses the Pentium table
	ghdl -i --std=08 --work=work $^
	ghdl -m --std=08 -fexplicit tb_srt
	ghdl -r --std=08 tb_srt -gG_PLA=$(PLA) --assert-level=error --stop-time=400ms

# Run only the first few divisions, and write a waveform to srt.ghw
.PHONY: debug
debug: $(SIM_SRC) ## Run the first 10 us of the testbench, and write a waveform to srt.ghw
	ghdl -i --std=08 --work=work $^
	ghdl -m --std=08 -fexplicit tb_srt
	ghdl -r --std=08 tb_srt -gG_PLA=$(PLA) --assert-level=error --wave=srt.ghw --stop-time=10us

# srt.gtkw selects the most relevant signals of srt, normalizer, srt_core,
# and shifter, for GTKWave (see https://github.com/gtkwave/gtkwave)
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave srt.ghw srt.gtkw


#######################
# Model
#######################

# Check the quotient digit table, and test the bit-exact model, both with a
# carry-save partial remainder (like srt_core.vhd) and with an exact one
.PHONY: model
model: ## Check the quotient digit table, and test the bit-exact model srt.py
	./srt.py
	./srt.py --exact


#######################
# Diagram of the table
#######################

# The diagram is included in ALGORITHM.md as pla.svg. pla.tex is drawn with
# TikZ (see https://tikz.dev/) and built with latexmk (see
# https://ctan.org/pkg/latexmk). pdftocairo, which is part of Poppler (see
# https://poppler.freedesktop.org/), converts the PDF to SVG.
pla_steps.tex: srt.py
	./srt.py --tikz > $@

pla.pdf: pla.tex pla_steps.tex
	latexmk -pdf pla.tex

pla.svg: pla.pdf ## Build the diagram of the table, used in ALGORITHM.md
	pdftocairo -svg $< $@


#######################
# Synthesis using Vivado
#######################

XILINX_DIR = /opt/Xilinx/2025.1/Vivado

VIVADO_SRC  = pla.vhd pla_pentium.vhd normalizer.vhd srt_core.vhd shifter.vhd srt.vhd
VIVADO_PART = xc7a200tfbg484-2
VIVADO_DIR  = vivado

# Synthesize and implement the design out of context (see vivado.tcl), and
# write the reports timing_summary.rpt and utilization.rpt to $(VIVADO_DIR).
# This fails if the design does not meet the clock constraint in srt.xdc. The
# project srt.xpr uses the same settings.
#
# -mode batch, NOT -mode tcl. In tcl mode Vivado exits 0 even when the sourced
# script raises an error, so an aborted build would be reported as success to
# make. Batch mode propagates the error as a non-zero exit status. The modes
# are described in UG894, "Vivado Design Suite User Guide: Using Tcl
# Scripting": https://docs.amd.com/r/en-US/ug894-vivado-tcl-scripting
.PHONY: vivado
vivado: $(VIVADO_DIR)/post_route.dcp ## Run synthesis and implementation using Vivado (about 2 minutes)

$(VIVADO_DIR)/post_route.dcp: vivado.tcl $(VIVADO_SRC) srt.xdc
	mkdir -p $(VIVADO_DIR)
	cd $(VIVADO_DIR) && bash -c "source $(XILINX_DIR)/settings64.sh ; \
	   vivado -mode batch -nojournal -log vivado.log -source $(CURDIR)/vivado.tcl \
	   -tclargs $(VIVADO_PART) $(CURDIR)"


#######################
# Formal verification
#######################

DUT  = srt_core
SRC += $(DUT).vhd
SRC += pla.vhd
SRC += pla_pentium.vhd

# This runs all the tasks defined in $(DUT).sby, using SymbiYosys (see
# https://github.com/YosysHQ/sby). "yosys -m ghdl" loads the GHDL plugin for
# Yosys (see https://github.com/ghdl/ghdl-yosys-plugin), which reads the VHDL
# and PSL files.
.PHONY: formal
formal: $(DUT).sby $(DUT).psl $(SRC) ## Run the formal verification of srt_core.vhd (about two minutes)
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

.PHONY: show_prove
show_prove: ## Show the counterexample from a failing "make formal" in GTKWave
	gtkwave $(DUT)_prove/engine_0/trace.vcd $(DUT).gtkw

.PHONY: show_induct
show_induct: ## Show the trace from a failing induction step in GTKWave
	gtkwave $(DUT)_prove/engine_0/trace_induct.vcd $(DUT).gtkw

.PHONY: show_cover
show_cover: ## Show the cover trace from "make formal" in GTKWave
	gtkwave $(DUT)_cover/engine_0/trace0.vcd $(DUT).gtkw


.PHONY: clean
clean: ## Remove the generated files
	rm -rf __pycache__ pla.pdf pla.aux pla.log pla.fls pla.fdb_latexmk tb_srt srt.ghw work-obj08.cf *.o $(DUT) $(DUT)_cover $(DUT)_prove $(DUT)_prove32
	rm -rf vivado .Xil

