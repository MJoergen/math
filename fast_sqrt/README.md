# Square root

This uses a simple bit-shifting algorithm to calculate the square root of a C64 floating
point number in 34 clock cycles.

It can safely run at a clock speed of 217 MHz (clock period 4.6 ns).

The resource usage is:

LUT   : 292
FF    : 167
Slice :  98

