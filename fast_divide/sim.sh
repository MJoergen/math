#!/bin/bash

SRC="fast_divide.vhd \
tb_fast_divide.vhd"

ghdl compile --std=08 $SRC -r tb_fast_divide --stop-time=1000us --wave=fast_divide.ghw
#gtkwave fast_divide.ghw fast_divide.gtkw

