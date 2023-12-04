# Pipelined Square Root calculation

This calculates the square root of a number with 21 bits of accuracy, i.e. more than six
decimal digits.

Input: The range of values is [1, 4[, and the value is encoded as fixed point 2.20.
       The integer part (upper two bits) must be nonzero.

Output: The range of values is [1, 2[, and the fractional part is encoded as fixed point
        0.22 (the integer part is constant 1).

## FPGA Reources
This implementation uses two BRAMs and one DSP, and a small amount of extra logic.

## Theory of operation
The calculation performed is x = sqrt(y), where y is the real input number and x is the
real output number.
The input number y is required to be in the range [1, 4[.

1. First the input number y is decomposed into two parts:
`y = a + b*eps`
where a is in the range [1, 4[, b is in the range [0, 1[, and eps = 2^(-9).
In this way, the value a can be
represented in fixed point 2.9 and the number b in fixed point 0.11

2. Second the number a is used as index into two lookup tables (BRAMs)
The first gives `f(a) = sqrt(a)-1` represented as fixed point 0.18
The second gives `g(a) = (2/sqrt(a))-1` represented as fixed point 0.18

3. The formula for calculating x = sqrt(y) is based on a Taylor
expansion to first order in eps:

In general we have `f(a+b*eps) == f(a) + f'(a)*b*eps`
where "==" means approximately equal to.

Here we use f(y) = sqrt(y), and we thus get
`sqrt(y) == sqrt(a) + (2/sqrt(a))*b*(eps/4)`

4. The above scheme only gives 18 bits of accuracy, and this limitation
is mainly from the first lookup table for f(a). So, to improve accuracy, the
function f(a) is calculated to 22 bits accuracy, and only the lower 18 bits are stored in
BRAM. The upper 4 bits are calculated combinatorially. This is controlled by the generic
G_EXTRA_BITS.

# Test results

To verify the implementation in simulation, there is a testbench that cycles through all
2^22 values of the input, and compares with the expected output. It prints out whenever
the error is larger than any previous error.

It takes approx 3 minutes to run the entire simulation for each value of G_EXTRA_BITS.

The shell script ghdl.sh runs the simulation five times for different values of
G_EXTRA_BITS.

The main results are:

## G_EXTRA_BITS = 0:

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  0x100401 |  0x000800  |  0x000801 |
|  0x100800 |  0x000FF0  |  0x000FFE |
|  0x100801 |  0x000FF1  |  0x001000 |
|  0x1039E4 |  0x007350  |  0x007360 |
|  0x10AA35 |  0x0150E2  |  0x0150F3 |

Maximal error is 0x000011, i.e. approx 2^4, so the accuracy
is 22-4 = 18 bits.

Analysis of the final row:
* data_in  = 0x10AA35
* sqrt_low = 0x014C9
* inv_sqrt = 0x3D64E
* data_lsb = 0x235
* b        = 0x235
* f        = 0x00532400000
* g        = 0x7D64E
* abc      = 0x005438BFA26
* data_out = 0x0150E2

Synthesis report
* BRAM = 2
* DSP  = 1
* LUT  = 0
* REG  = 0


## G_EXTRA_BITS = 1:

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  0x100401 |  0x000800  |  0x000801 |
|  0x100800 |  0x000FF8  |  0x000FFE |
|  0x100801 |  0x000FF9  |  0x001000 |
|  0x1039E4 |  0x007358  |  0x007360 |
|  0x1080DF |  0x00FFB6  |  0x00FFBF |

Maximal error is 0x000009, i.e. approx 2^3, so the accuracy
is 22-3 = 19 bits.

Analysis of the final row:
* data_in   = 0x1080DF
* sqrt_low  = 0x01FC0
* sqrt_high = 0x0
* inv_sqrt  = 0x3DFC6
* data_lsb  = 0x0DF
* b         = 0x0DF
* f         = 0x003F8000000
* g         = 0x7DFC6
* abc       = 0x003FEDBED7A
* data_out  = 0x00FFB6

Synthesis report
* LUT  = 1
* REG  = 2
* BRAM = 2
* DSP  = 1


## G_EXTRA_BITS = 2:

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  0x100401 |  0x000800  |  0x000801 |
|  0x100800 |  0x000FFC  |  0x000FFE |
|  0x100801 |  0x000FFD  |  0x001000 |
|  0x1039E4 |  0x00735C  |  0x007360 |
|  0x1080DF |  0x00FFBA  |  0x00FFBF |

Maximal error is 0x000005, i.e. approx 2^2, so the accuracy
is 22-2 = 20 bits.

Analysis of the final row:
* data_in   = 0x1080DF
* sqrt_low  = 0x03F81
* sqrt_high = 0x0
* inv_sqrt  = 0x3DFC6
* data_lsb  = 0x0DF
* b         = 0x0DF
* f         = 0x003F8100000
* g         = 0x7DFC6
* abc       = 0x003FEEBED7A
* data_out  = 0x00FFBA

Synthesis report
* LUT  = 2
* REG  = 4
* BRAM = 2
* DSP  = 1


## G_EXTRA_BITS = 3:

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  0x100401 |  0x000800  |  0x000801 |
|  0x1039E4 |  0x00735E  |  0x007360 |
|  0x105064 |  0x009FFD  |  0x00A000 |

Maximal error is 0x000003, i.e. approx 2^1, so the accuracy
is 22-1 = 21 bits.

Analysis of the final row:
* data_in   = 0x105064
* sqrt_low  = 0x04F9C
* sqrt_high = 0x0
* inv_sqrt  = 0x3EB51
* data_lsb  = 0x064
* b         = 0x064
* f         = 0x0027CE00000
* g         = 0x7EB51
* abc       = 0x0027FF7EBA4
* data_out  = 0x009FFD

Synthesis report
* LUT  = 6
* REG  = 6
* BRAM = 2
* DSP  = 1


## G_EXTRA_BITS = 4:

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  0x100401 |  0x000800  |  0x000801 |
|  0x1039E4 |  0x00735E  |  0x007360 |

Maximal error is 0x000002, i.e. approx 2^1, so the accuracy
is 22-1 = 21 bits.

Analysis of the final row:
* data_in   = 0x1039E4
* sqrt_low  = 0x06F9E
* sqrt_high = 0x0
* inv_sqrt  = 0x3F129
* data_lsb  = 0x1E4
* b         = 0x1E4
* f         = 0x001BE780000
* g         = 0x7F129
* abc       = 0x001CD7BF184
* data_out  = 0x00735E

Synthesis report
* LUT   = 13
* REG   = 8
* F7MUX = 3
* F8MUX = 1
* BRAM  = 2
* DSP   = 1


