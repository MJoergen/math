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

SRC = dsp.vhd fast_sqrt2.vhd tb_fast_sqrt2.vhd

# The testbench calculates the square root of 0, 1, 2, 3, 4, 0.5, and -1
# (which gives an error), and of 15938 values from 0.031 to 8, and prints the
# average number of clock cycles per calculation. The last bit of the mantissa
# is not always exact, see README.md, so the mismatches are reported, but they
# do not stop the simulation.
.PHONY: sim
sim: $(SRC) ## Run the testbench (about 20 seconds)
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_fast_sqrt2
	ghdl -r --std=08 tb_fast_sqrt2 --stop-time=6000us

# The same, but also write a waveform (about 33 MB)
.PHONY: debug
debug: $(SRC) ## Run the testbench, and write a waveform to fast_sqrt2.ghw
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_fast_sqrt2
	ghdl -r --std=08 tb_fast_sqrt2 --stop-time=6000us --wave=fast_sqrt2.ghw

# GTKWave, see https://github.com/gtkwave/gtkwave
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave fast_sqrt2.ghw fast_sqrt2.gtkw


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_fast_sqrt2 fast_sqrt2.ghw
