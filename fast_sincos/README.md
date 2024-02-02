# Sine and cosine

This uses the CORDIC algorithm to calculate the sine and cosine of a C64 floating
point number in 42 clock cycles.

It can safely run at a clock speed of 161 MHz (clock period 6.2 ns). The total latency is
thus 260 ns.

The resource usage is:

* LUT   : 1028
* FF    :  379
* Slice :  314
* DSP   :    4

