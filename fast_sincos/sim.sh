#!/bin/bash

SRC="fast_sincos.vhd \
fast_sincos_pkg.vhd \
fast_sincos_rom.vhd \
fast_sincos_rotate.vhd \
fast_sincos_addsub.vhd \
tb_fast_sincos.vhd"

rm fast_sincos.ghw
ghdl compile --std=08 $SRC -r tb_fast_sincos --stop-time=6000us --wave=fast_sincos.ghw
#gtkwave fast_sincos.ghw fast_sincos.gtkw

