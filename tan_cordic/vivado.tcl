# Synthesis and implementation of tan_cordic.vhd with Vivado, see
# "make vivado" in the Makefile. The Tcl commands are described in UG835,
# "Vivado Design Suite Tcl Command Reference Guide":
# https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands
#
# Arguments (after -tclargs): <G_ITERATIONS> <G_FRAC_BITS> <part> <source directory>
#
# The design is synthesized out of context (-mode out_of_context), i.e. as a
# module inside a larger design: No I/O buffers are inserted, and no I/O pins
# are assigned. So the timing only covers the paths between registers, with
# the clock in tan_cordic.xdc.
#
# The reports are written to the current directory. The build fails if the
# design does not meet timing, and the routed checkpoint post_route.dcp is
# only written if it does.

lassign $argv iterations frac_bits part src

read_vhdl -vhdl2008 [file join $src tan_cordic.vhd]
read_xdc -mode out_of_context [file join $src tan_cordic.xdc]

synth_design -top tan_cordic -part $part -mode out_of_context \
   -generic G_ITERATIONS=$iterations -generic G_FRAC_BITS=$frac_bits
opt_design
place_design
phys_opt_design
route_design

report_timing_summary -file timing_summary.rpt
report_utilization -file utilization.rpt

# A summary for the terminal: The number of cells, and the slack and logic
# levels of the worst path
set path  [get_timing_paths]
set slack [get_property SLACK $path]
set luts  [llength [get_cells -hierarchical -filter {PRIMITIVE_GROUP == LUT}]]
set ffs   [llength [get_cells -hierarchical -filter {PRIMITIVE_GROUP == FLOP_LATCH}]]
set dsps  [llength [get_cells -hierarchical -filter {REF_NAME =~ DSP48*}]]
puts "SUMMARY: tan_cordic, G_ITERATIONS=$iterations, G_FRAC_BITS=$frac_bits:\
      LUT $luts, FF $ffs, DSP $dsps,\
      worst path: slack $slack ns, [get_property LOGIC_LEVELS $path] logic levels,\
      from [get_property STARTPOINT_PIN $path] to [get_property ENDPOINT_PIN $path]"

if {$slack < 0} {
   puts "TIMING VIOLATED -- see timing_summary.rpt"
   exit 1
}

write_checkpoint -force post_route.dcp
