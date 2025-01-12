~/bin/srt: srt.cpp
	gcc srt.cpp -lm -o ~/bin/srt

sim: srt_float.vhd pla.vhd normalizer.vhd div.vhd shifter.vhd tb_srt.vhd
	ghdl -i --std=08 --work=work $^
	ghdl -m --std=08 -fexplicit tb_srt
	ghdl -r --std=08 tb_srt --assert-level=error --wave=srt.ghw --stop-time=400ms

