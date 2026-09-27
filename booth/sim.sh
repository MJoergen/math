#!/bin/bash
set -e

SRC="booth.vhd \
tb_booth.vhd"

ghdl -a --std=08 $SRC
ghdl -e --std=08 tb_booth

# Exhaustive tests for small sizes, with random stalls
for size in 1 2 3 4 5 6 7; do
   ghdl -r --std=08 tb_booth -gG_DATA_SIZE=$size --assert-level=error
done

# Random tests for larger sizes, with random stalls
for size in 16 32; do
   ghdl -r --std=08 tb_booth -gG_DATA_SIZE=$size -gG_EXHAUSTIVE=false --assert-level=error
done

# Verify throughput without stalls
ghdl -r --std=08 tb_booth -gG_DATA_SIZE=8 -gG_EXHAUSTIVE=false -gG_VALID_PCT=100 -gG_READY_PCT=100 --assert-level=error

# Only a slow consumer
ghdl -r --std=08 tb_booth -gG_DATA_SIZE=8 -gG_EXHAUSTIVE=false -gG_VALID_PCT=100 -gG_READY_PCT=10 --assert-level=error

# Waveform for inspection
#ghdl -r --std=08 tb_booth -gG_DATA_SIZE=8 -gG_EXHAUSTIVE=false -gG_NUM_TESTS=20 --wave=booth.ghw
#gtkwave booth.ghw
