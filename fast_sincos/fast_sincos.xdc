# This file is specific for the Nexys 4 DDR board.

# Clock definition
create_clock -name sys_clk -period 5.4 [get_ports {clk_i}]; # 185 MHz

# Configuration Bank Voltage Select
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

