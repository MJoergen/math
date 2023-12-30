#!/bin/bash

SRC="dsp.vhd \
fast_sqrt2.vhd \
tb_fast_sqrt2.vhd"

rm fast_sqrt2.ghw
ghdl compile --std=08 $SRC -r tb_fast_sqrt2 --stop-time=6000us --wave=fast_sqrt2.ghw
gtkwave fast_sqrt2.ghw fast_sqrt2.gtkw

