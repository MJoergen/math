#!/bin/bash
# Run the testbench tb_booth.vhd with GHDL (https://github.com/ghdl/ghdl), for
# both booth.vhd (radix 4) and booth_radix2.vhd (radix 2). See "Simulation" in
# README.md.
set -e
cd "$(dirname "$0")"

SRC="booth.vhd \
booth_radix2.vhd \
tb_booth.vhd"

ghdl -a --std=08 $SRC
ghdl -e --std=08 tb_booth

for radix in 4 2; do
   RUN="ghdl -r --std=08 tb_booth -gG_RADIX=$radix --assert-level=error"

   # Exhaustive tests for small sizes, with random stalls
   for size in 1 2 3 4 5 6 7; do
      $RUN -gG_DATA_SIZE=$size
   done

   # Random tests for larger sizes, with random stalls
   for size in 16 17 32; do
      $RUN -gG_DATA_SIZE=$size -gG_EXHAUSTIVE=false
   done

   # Verify throughput without stalls (for both even and odd sizes)
   $RUN -gG_DATA_SIZE=9 -gG_EXHAUSTIVE=false -gG_VALID_PCT=100 -gG_READY_PCT=100
   $RUN -gG_DATA_SIZE=8 -gG_EXHAUSTIVE=false -gG_VALID_PCT=100 -gG_READY_PCT=100

   # Only a slow consumer
   $RUN -gG_DATA_SIZE=8 -gG_EXHAUSTIVE=false -gG_VALID_PCT=100 -gG_READY_PCT=10
done

echo "All tests passed"

# Waveform for inspection
#ghdl -r --std=08 tb_booth -gG_DATA_SIZE=8 -gG_EXHAUSTIVE=false -gG_NUM_TESTS=20 --wave=booth.ghw
#gtkwave booth.ghw
