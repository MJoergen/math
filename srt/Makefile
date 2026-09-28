# Default target: Simulate the VHDL design
.PHONY: all
all: sim


#######################
# Simulation
#######################

SIM_SRC = srt_float.vhd pla.vhd normalizer.vhd div.vhd shifter.vhd tb_srt.vhd

# Run the complete testbench. No waveform is written, since a waveform of the
# complete run is several GB, and makes GHDL crash.
.PHONY: sim
sim: $(SIM_SRC)
	ghdl -i --std=08 --work=work $^
	ghdl -m --std=08 -fexplicit tb_srt
	ghdl -r --std=08 tb_srt --assert-level=error --stop-time=400ms

# Run only the first few divisions, and write a waveform to srt.ghw
.PHONY: debug
debug: $(SIM_SRC)
	ghdl -i --std=08 --work=work $^
	ghdl -m --std=08 -fexplicit tb_srt
	ghdl -r --std=08 tb_srt --assert-level=error --wave=srt.ghw --stop-time=10us

.PHONY: show_debug
show_debug:
	gtkwave srt.ghw


#######################
# Model
#######################

# Check the quotient digit table, and test the bit-exact model
.PHONY: model
model:
	./srt.py


#######################
# Diagram of the table
#######################

# The diagram is included in ALGORITHM.md as pla.svg
pla_steps.tex: srt.py
	./srt.py --tikz > $@

pla.pdf: pla.tex pla_steps.tex
	latexmk -pdf pla.tex

pla.svg: pla.pdf
	pdftocairo -svg $< $@


#######################
# Formal verification
#######################

DUT  = div
SRC += $(DUT).vhd
SRC += pla.vhd

# This runs both the "cover" and the "bmc" tasks defined in $(DUT).sby
.PHONY: formal
formal: $(DUT).sby $(DUT).psl $(SRC)
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

.PHONY: show_bmc
show_bmc:
	gtkwave $(DUT)_bmc/engine_0/trace.vcd $(DUT).gtkw

.PHONY: show_cover
show_cover:
	gtkwave $(DUT)_cover/engine_0/trace0.vcd $(DUT).gtkw


.PHONY: clean
clean:
	rm -rf __pycache__ pla.pdf pla.aux pla.log pla.fls pla.fdb_latexmk tb_srt srt.ghw work-obj08.cf *.o $(DUT)_cover $(DUT)_bmc

