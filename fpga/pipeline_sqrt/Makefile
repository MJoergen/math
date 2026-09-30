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
# all 3*2^20 valid inputs, from 0x100000 to 0x3FFFFF, and prints each result
# whose error is larger than any previous error. The testbench stops the clock
# after the last input (at about 31.5 ms), so --stop-time is just a safeguard.
.PHONY: sim
sim: $(SRC) ## Run the testbench for G_EXTRA_BITS from 0 to 4 (about 3 to 4 minutes each)
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_pipeline_sqrt
	set -e; for bits in $(EXTRA_BITS); do \
	   echo "G_EXTRA_BITS=$$bits"; \
	   ghdl -r --std=08 tb_pipeline_sqrt -gG_EXTRA_BITS=$$bits --stop-time=50ms --assert-level=error; \
	done

# A short run, which writes about 25 us of waveform
.PHONY: debug
debug: $(SRC) ## Run the testbench shortly with G_EXTRA_BITS=2, and write a waveform to pipeline_sqrt.ghw
	ghdl -a --std=08 $(SRC)
	ghdl -e --std=08 tb_pipeline_sqrt
	ghdl -r --std=08 tb_pipeline_sqrt -gG_EXTRA_BITS=2 --stop-time=25us --wave=pipeline_sqrt.ghw

# GTKWave, see https://github.com/gtkwave/gtkwave
.PHONY: show_debug
show_debug: ## Show the waveform from "make debug" in GTKWave
	gtkwave pipeline_sqrt.ghw pipeline_sqrt.gtkw


.PHONY: clean
clean: ## Remove the generated files
	rm -rf work-obj08.cf *.o tb_pipeline_sqrt pipeline_sqrt.ghw
