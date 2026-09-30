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


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_fast_sincos fast_sincos.ghw
