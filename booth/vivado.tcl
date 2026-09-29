# Synthesis and implementation of booth.vhd or booth_radix2.vhd with Vivado,
# see "make vivado" in the Makefile. The Tcl commands are described in UG835,
# "Vivado Design Suite Tcl Command Reference Guide":
# https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands
#
# Arguments (after -tclargs): <top> <G_DATA_SIZE> <part> <source directory>
#
# The design is synthesized out of context (-mode out_of_context), i.e. as a
# module inside a larger design: No I/O buffers are inserted, and no I/O pins
# are assigned. So the timing only covers the paths between registers, with
# the clock in booth.xdc.
#
# The reports are written to the current directory. The build fails if the
# design does not meet timing, and the routed checkpoint post_route.dcp is
# only written if it does.

lassign $argv top size part src

read_vhdl -vhdl2008 [file join $src $top.vhd]
read_xdc -mode out_of_context [file join $src booth.xdc]

synth_design -top $top -part $part -mode out_of_context -generic G_DATA_SIZE=$size
opt_design
place_design
phys_opt_design
route_design

report_timing_summary -file timing_summary.rpt
report_utilization -file utilization.rpt

# A summary for the terminal, comparable with "make synth": The number of
# cells, and the slack and logic levels of the worst path
set path  [get_timing_paths]
set slack [get_property SLACK $path]
set luts  [llength [get_cells -hierarchical -filter {PRIMITIVE_GROUP == LUT}]]
set ffs   [llength [get_cells -hierarchical -filter {PRIMITIVE_GROUP == FLOP_LATCH}]]
set carry [llength [get_cells -hierarchical -filter {REF_NAME == CARRY4}]]
puts "SUMMARY: $top, G_DATA_SIZE=$size: LUT $luts, FF $ffs, CARRY4 $carry,\
      worst path: slack $slack ns, [get_property LOGIC_LEVELS $path] logic levels"

if {$slack < 0} {
   puts "TIMING VIOLATED -- see timing_summary.rpt"
   exit 1
}

write_checkpoint -force post_route.dcp
