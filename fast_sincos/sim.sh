#!/bin/bash

SRC="fast_sincos.vhd \
tb_fast_sincos.vhd"

rm fast_sincos.ghw
ghdl compile --std=08 $SRC -r tb_fast_sincos --stop-time=6000us --wave=fast_sincos.ghw
gtkwave fast_sincos.ghw fast_sincos.gtkw

