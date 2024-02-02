# Sine and cosine

This uses the CORDIC algorithm to calculate the sine and cosine of a C64 floating
point number in 36 clock cycles.

It can safely run at a clock speed of 156 MHz (clock period 6.4 ns). The total latency is
thus 230 ns.

The resource usage is:

* LUT   : 1077
* FF    :  384
* Slice :  308
* DSP   :    4

The absolute deviation for angles in the range [0, pi/4] is 2^(-32).
The absolute deviation for angles in the range [-2pi, 2pi] is 2^(-26).


