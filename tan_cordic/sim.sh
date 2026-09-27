#!/bin/bash
set -e

SRC="tan_cordic.vhd \
tb_tan_cordic.vhd"

ghdl -a --std=08 $SRC
ghdl -e --std=08 tb_tan_cordic

# Sweep a range of iteration counts and fractional-bit widths, with random stalls
for iterations in 4 8 12 16 20; do
   for frac_bits in 8 16 20 24 28; do
      ghdl -r --std=08 tb_tan_cordic -gG_ITERATIONS=$iterations -gG_FRAC_BITS=$frac_bits \
         -gG_NUM_TESTS=150 --assert-level=error
   done
done

# Verify throughput without stalls, and with a slow consumer / slow producer
ghdl -r --std=08 tb_tan_cordic -gG_NUM_TESTS=500 -gG_VALID_PCT=100 -gG_READY_PCT=100 --assert-level=error
ghdl -r --std=08 tb_tan_cordic -gG_NUM_TESTS=500 -gG_VALID_PCT=100 -gG_READY_PCT=10  --assert-level=error
ghdl -r --std=08 tb_tan_cordic -gG_NUM_TESTS=500 -gG_VALID_PCT=10  -gG_READY_PCT=100 --assert-level=error

# Larger run at the default configuration
ghdl -r --std=08 tb_tan_cordic -gG_NUM_TESTS=5000 --assert-level=error

# Waveform for inspection
#ghdl -r --std=08 tb_tan_cordic -gG_NUM_TESTS=20 --wave=tan_cordic.ghw
#gtkwave tan_cordic.ghw
