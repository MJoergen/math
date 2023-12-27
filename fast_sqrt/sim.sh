#!/bin/bash

SRC="fast_sqrt.vhd \
tb_fast_sqrt.vhd"

ghdl compile --std=08 $SRC -r tb_fast_sqrt --stop-time=2000us --wave=fast_sqrt.ghw
gtkwave fast_sqrt.ghw fast_sqrt.gtkw

