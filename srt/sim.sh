#!/bin/bash

SRC="fast_divide2.vhd \
tb_fast_divide2.vhd"

ghdl compile --std=08 $SRC -r tb_fast_divide2 --stop-time=2000us --wave=fast_divide2.ghw
#gtkwave fast_divide2.ghw fast_divide2.gtkw

