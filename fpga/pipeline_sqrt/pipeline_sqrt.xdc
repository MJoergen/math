# Timing constraints for synthesizing pipeline_sqrt.vhd in Vivado, both with
# "make vivado" (see the Makefile) and in the project pipeline_sqrt.xpr. The XDC
# format is described in UG903, "Vivado Design Suite User Guide: Using
# Constraints": https://docs.amd.com/r/en-US/ug903-vivado-using-constraints
#
# The design is synthesized out of context, i.e. as a module inside a larger
# design, so no I/O pins are assigned, and only the paths between registers
# are timed.

# Clock definition. For create_clock, see UG903 above, and UG835, "Vivado
# Design Suite Tcl Command Reference Guide":
# https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands
# 4.5 ns is the shortest clock period found where the timing is met. With a
# clock period of 7.5 ns or less, Vivado 2025.1 synthesis implements some or
# all of the ROMs in LUTs instead of Block RAM, and at 4.5 ns all of them, see
# README.md.
create_clock -name clk -period 4.50 [get_ports {clk_i}]; # 222 MHz

# In a real design, the clock comes from a global clock buffer. Without this
# property, the timing out of context only estimates the clock delay and skew.
# See "Out-of-Context Design Constraints" in UG905, "Vivado Design Suite User
# Guide: Hierarchical Design":
# https://docs.amd.com/r/en-US/ug905-vivado-hierarchical-design
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports {clk_i}]
