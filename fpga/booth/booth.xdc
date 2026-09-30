# Timing constraints for synthesizing booth.vhd or booth_radix2.vhd in Vivado,
# see "make vivado" in the Makefile. The XDC format is described in UG903,
# "Vivado Design Suite User Guide: Using Constraints":
# https://docs.amd.com/r/en-US/ug903-vivado-using-constraints
#
# The design is synthesized out of context, i.e. as a module inside a larger
# design, so no I/O pins are assigned, and only the paths between registers
# are timed.

# Clock definition. For create_clock, see UG903 above, and UG835, "Vivado
# Design Suite Tcl Command Reference Guide":
# https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands
#
# With Vivado 2025.1, booth.vhd meets 250 MHz with a slack of about 1.2 ns for
# G_DATA_SIZE=16, 0.8 ns for 32, and 0.3 ns for 64. The critical path is the
# carry chain of the adder, see "Timing" in ALGORITHM.md.
create_clock -name clk -period 4.00 [get_ports {clk_i}]; # 250 MHz

# In a real design, the clock comes from a global clock buffer. Without this
# property, the timing out of context only estimates the clock delay and skew.
# See "Out-of-Context Design Constraints" in UG905, "Vivado Design Suite User
# Guide: Hierarchical Design":
# https://docs.amd.com/r/en-US/ug905-vivado-hierarchical-design
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports {clk_i}]
