# Test results

It takes approx 3 minutes to run the entire simulation.
The main results are:

## C_EXTRA_BITS = 0:

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  100401 |  000800  |  000801 |
|  100800 |  000FF0  |  000FFE |
|  100801 |  000FF1  |  001000 |
|  1039E4 |  007350  |  007360 |
|  10AA35 |  0150E2  |  0150F3 |

Maximal error is 000011, i.e. approx 2^4, so the accuracy
is 22-4 = 18 bits.

Analysis of the final row:
* data_in  = 10AA35
* sqrt_low = 014C9
* inv_sqrt = 3D64E
* data_lsb = 235
* b        = 235
* f        = 00532400000
* g        = 7D64E
* abc      = 005438BFA26
* data_out = 0150E2

Synthesis report
* BRAM = 2
* DSP  = 1
* LUT  = 0
* REG  = 0


## C_EXTRA_BITS = 1:

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  100401 |  000800  |  000801 |
|  100800 |  000FF8  |  000FFE |
|  100801 |  000FF9  |  001000 |
|  1039E4 |  007358  |  007360 |
|  1080DF |  00FFB6  |  00FFBF |

Maximal error is 000009, i.e. approx 2^3, so the accuracy
is 22-3 = 19 bits.

Analysis of the final row:
* data_in   = 1080DF
* sqrt_low  = 01FC0
* sqrt_high = 0
* inv_sqrt  = 3DFC6
* data_lsb  = 0DF
* b         = 0DF
* f         = 003F8000000
* g         = 7DFC6
* abc       = 003FEDBED7A
* data_out  = 00FFB6

Synthesis report
* LUT  = 1
* REG  = 2
* BRAM = 2
* DSP  = 1


## C_EXTRA_BITS = 2:

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  100401 |  000800  |  000801 |
|  100800 |  000FFC  |  000FFE |
|  100801 |  000FFD  |  001000 |
|  1039E4 |  00735C  |  007360 |
|  1080DF |  00FFBA  |  00FFBF |

Maximal error is 000005, i.e. approx 2^2, so the accuracy
is 22-2 = 20 bits.

Analysis of the final row:
* data_in   = 1080DF
* sqrt_low  = 03F81
* sqrt_high = 0
* inv_sqrt  = 3DFC6
* data_lsb  = 0DF
* b         = 0DF
* f         = 003F8100000
* g         = 7DFC6
* abc       = 003FEEBED7A
* data_out  = 00FFBA

Synthesis report
* LUT  = 2
* REG  = 4
* BRAM = 2
* DSP  = 1


## C_EXTRA_BITS = 3:

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  100401 |  000800  |  000801 |
|  1039E4 |  00735E  |  007360 |
|  105064 |  009FFD  |  00A000 |

Maximal error is 000003, i.e. approx 2^1, so the accuracy
is 22-1 = 21 bits.

Analysis of the final row:
* data_in   = 105064
* sqrt_low  = 04F9C
* sqrt_high = 0
* inv_sqrt  = 3EB51
* data_lsb  = 064
* b         = 064
* f         = 0027CE00000
* g         = 7EB51
* abc       = 0027FF7EBA4
* data_out  = 009FFD

Synthesis report
* LUT  = 6
* REG  = 6
* BRAM = 2
* DSP  = 1


## C_EXTRA_BITS = 4:

| data_in | data_out | exp_out |
| ------- | -------- | ------- |
|  100401 |  000800  |  000801 |
|  1039E4 |  00735E  |  007360 |

Maximal error is 000002, i.e. approx 2^1, so the accuracy
is 22-1 = 21 bits.

Analysis of the final row:
* data_in   = 1039E4
* sqrt_low  = 06F9E
* sqrt_high = 0
* inv_sqrt  = 3F129
* data_lsb  = 1E4
* b         = 1E4
* f         = 001BE780000
* g         = 7F129
* abc       = 001CD7BF184
* data_out  = 00735E

Synthesis report
* LUT   = 13
* REG   = 8
* F7MUX = 3
* F8MUX = 1
* BRAM  = 2
* DSP   = 1


