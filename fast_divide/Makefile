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

SRC = fast_divide.vhd tb_fast_divide.vhd

# The testbench divides all pairs of numerator and denominator from 1 to 100,
# and prints the average number of clock cycles per division. The last bits
# of the fraction are not always exact, see README.md, so the mismatches are
# reported, but they do not stop the simulation.
.PHONY: sim
sim: $(SRC) ## Run the testbench (about 10 seconds)
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_fast_divide
	ghdl -r --std=08 tb_fast_divide --stop-time=2000us

# The same, but also write a waveform
.PHONY: debug
debug: $(SRC) ## Run the testbench, and write a waveform to fast_divide.ghw
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_fast_divide
	ghdl -r --std=08 tb_fast_divide --stop-time=2000us --wave=fast_divide.ghw

# GTKWave, see https://github.com/gtkwave/gtkwave
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave fast_divide.ghw fast_divide.gtkw


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_fast_divide fast_divide.ghw
