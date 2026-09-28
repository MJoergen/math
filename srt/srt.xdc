# Timing constraints for synthesizing srt in Vivado.
#
# The project (srt.xpr) targets the Artix-7 part xc7a200tfbg484-2. No I/O pins
# are assigned, so this is only used to check that the design meets timing.

# Clock definition
create_clock -name sys_clk -period 5.00 [get_ports {clk_i}]; # 200 MHz

# Configuration Bank Voltage Select
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

