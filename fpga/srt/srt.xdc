# Timing constraints for synthesizing srt in Vivado. The XDC format is
# described in UG903, "Vivado Design Suite User Guide: Using Constraints":
# https://docs.amd.com/r/en-US/ug903-vivado-using-constraints
#
# The project (srt.xpr) targets the Artix-7 part xc7a200tfbg484-2 (see
# https://www.amd.com/en/products/adaptive-socs-and-fpgas/fpga/artix-7.html).
# No I/O pins are assigned, so this is only used to check that the design
# meets timing.

# Clock definition. For create_clock, see UG903 above, and UG835, "Vivado
# Design Suite Tcl Command Reference Guide":
# https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands
create_clock -name clk -period 5.00 [get_ports {clk_i}]; # 200 MHz

# Configuration Bank Voltage Select. The properties CFGBVS and CONFIG_VOLTAGE
# are described in UG912, "Vivado Design Suite Properties Reference Guide":
# https://docs.amd.com/r/en-US/ug912-vivado-properties
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

