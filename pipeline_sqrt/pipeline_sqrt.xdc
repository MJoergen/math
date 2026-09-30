# Clock definition. With a clock period of 7.5 ns or less, Vivado 2025.1
# synthesis implements some or all of the ROMs in LUTs instead of Block RAM.
create_clock -name sys_clk -period 8.0 [get_ports {clk_i}]; # 125 MHz
