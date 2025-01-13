~/bin/srt: srt.cpp
	gcc srt.cpp -lm -o ~/bin/srt

sim: srt_float.vhd pla.vhd normalizer.vhd div.vhd shifter.vhd tb_srt.vhd
	ghdl -i --std=08 --work=work $^
	ghdl -m --std=08 -fexplicit tb_srt
	ghdl -r --std=08 tb_srt --assert-level=error --wave=srt.ghw --stop-time=400ms

#######################
# Formal verification
#######################

DUT  = div
SRC += $(DUT).vhd
SRC += pla.vhd

.PHONY: formal
formal: $(DUT)_cover/PASS $(DUT)_bmc/PASS
$(DUT)_cover/PASS: $(DUT).sby $(DUT).psl $(SRC)
	# This is the main command line to run the formal verification
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

show_bmc:
	gtkwave $(DUT)_bmc/engine_0/trace.vcd $(DUT).gtkw

show_cover:
	gtkwave $(DUT)_cover/engine_0/trace0.vcd $(DUT).gtkw


