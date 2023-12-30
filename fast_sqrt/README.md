# Square root

This uses a simple bit-shifting algorithm to calculate the square root of a C64 floating
point number in 34 clock cycles.

It can safely run at a clock speed of 217 MHz (clock period 4.6 ns). The total latency is
thus 157 ns.

The resource usage is:

* LUT   : 283
* FF    : 208
* Slice : 103

