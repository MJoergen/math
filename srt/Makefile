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

SIM_SRC = srt_float.vhd pla.vhd normalizer.vhd div.vhd shifter.vhd tb_srt.vhd

# Run the complete testbench. No waveform is written, since a waveform of the
# complete run is several GB, and makes GHDL crash.
.PHONY: sim
sim: $(SIM_SRC) ## Run the complete testbench (takes about 15 minutes)
	ghdl -i --std=08 --work=work $^
	ghdl -m --std=08 -fexplicit tb_srt
	ghdl -r --std=08 tb_srt --assert-level=error --stop-time=400ms

# Run only the first few divisions, and write a waveform to srt.ghw
.PHONY: debug
debug: $(SIM_SRC) ## Run the first 10 us of the testbench, and write a waveform to srt.ghw
	ghdl -i --std=08 --work=work $^
	ghdl -m --std=08 -fexplicit tb_srt
	ghdl -r --std=08 tb_srt --assert-level=error --wave=srt.ghw --stop-time=10us

.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave srt.ghw


#######################
# Model
#######################

# Check the quotient digit table, and test the bit-exact model
.PHONY: model
model: ## Check the quotient digit table, and test the bit-exact model srt.py
	./srt.py


#######################
# Diagram of the table
#######################

# The diagram is included in ALGORITHM.md as pla.svg
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

VIVADO_TOP  = srt_float
VIVADO_PART = xc7a200tfbg484-2
VIVADO_SRC  = pla.vhd normalizer.vhd div.vhd shifter.vhd srt_float.vhd

# -mode batch, NOT -mode tcl. In tcl mode Vivado exits 0 even when the sourced
# script raises an error, so an aborted build -- on the timing check below, or
# inside synth_design/route_design -- would otherwise be reported as success
# to make. Batch mode propagates the error as a non-zero exit status.
.PHONY: vivado
vivado: $(VIVADO_TOP).bit ## Run synthesis and implementation using Vivado (batch mode)

$(VIVADO_TOP).bit: vivado_build.tcl $(VIVADO_SRC) srt.xdc
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode batch -source $<"

# report_timing_summary writes timing_summary.rpt next to the bitstream, and
# the check after it aborts the build on negative slack. write_bitstream
# succeeds even when timing is violated, so without that check a bitstream is
# not evidence that the design meets the 200 MHz constraint in srt.xdc.
vivado_build.tcl: Makefile
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "read_vhdl -vhdl2008 { $(VIVADO_SRC) }" >> $@
	echo "read_xdc srt.xdc" >> $@
	echo "synth_design -top $(VIVADO_TOP) -part $(VIVADO_PART)" >> $@
	echo "write_checkpoint -force post_synth.dcp" >> $@
	echo "opt_design" >> $@
	echo "place_design" >> $@
	echo "phys_opt_design" >> $@
	echo "route_design" >> $@
	echo "phys_opt_design" >> $@
	echo "write_checkpoint -force post_route.dcp" >> $@
	echo "report_timing_summary -file timing_summary.rpt" >> $@
	echo "report_utilization -file utilization.rpt" >> $@
	echo "if {[get_property SLACK [get_timing_paths]] < 0} { puts {TIMING VIOLATED -- see timing_summary.rpt} ; exit 1 }" >> $@
	echo "write_bitstream -force $(VIVADO_TOP).bit" >> $@
	echo "exit" >> $@


#######################
# Formal verification
#######################

DUT  = div
SRC += $(DUT).vhd
SRC += pla.vhd

# This runs both the "cover" and the "bmc" tasks defined in $(DUT).sby
.PHONY: formal
formal: $(DUT).sby $(DUT).psl $(SRC) ## Run the formal verification of div.vhd (takes about 25 minutes)
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

.PHONY: show_bmc
show_bmc: ## Show the counterexample from a failing "make formal" in GTKWave
	gtkwave $(DUT)_bmc/engine_0/trace.vcd $(DUT).gtkw

.PHONY: show_cover
show_cover: ## Show the cover trace from "make formal" in GTKWave
	gtkwave $(DUT)_cover/engine_0/trace0.vcd $(DUT).gtkw


.PHONY: clean
clean: ## Remove the generated files
	rm -rf __pycache__ pla.pdf pla.aux pla.log pla.fls pla.fdb_latexmk tb_srt srt.ghw work-obj08.cf *.o $(DUT)_cover $(DUT)_bmc
	rm -rf vivado_build.tcl post_synth.dcp post_route.dcp timing_summary.rpt utilization.rpt $(VIVADO_TOP).bit
	rm -rf vivado*.jou vivado*.log usage_statistics_webtalk* .Xil
	rm -rf clockInfo.txt tight_setup_hold_pins.txt

