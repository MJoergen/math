# Default target: Simulate the VHDL design
.PHONY: all
all: sim


#######################
# Simulation
#######################

.PHONY: sim
sim: srt_float.vhd pla.vhd normalizer.vhd div.vhd shifter.vhd tb_srt.vhd
	ghdl -i --std=08 --work=work $^
	ghdl -m --std=08 -fexplicit tb_srt
	ghdl -r --std=08 tb_srt --assert-level=error --wave=srt.ghw --stop-time=400ms


#######################
# Reference model
#######################

srt: srt.cpp
	g++ -O2 -Wall srt.cpp -o srt


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
	rm -rf srt tb_srt srt.ghw work-obj08.cf *.o $(DUT)_cover $(DUT)_bmc

