# Square root

This uses a simple bit-shifting algorithm to calculate the square root of a C64 floating
point number in 34 clock cycles.

It can safely run at a clock speed of 256 MHz (clock period 3.9 ns). The total latency is
thus 133 ns.

The resource usage is:

* LUT   : 167
* FF    : 111
* Slice :  67

