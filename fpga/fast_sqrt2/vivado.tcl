# Synthesis and implementation of fast_sqrt2.vhd with Vivado, see "make vivado" in
# the Makefile. The Tcl commands are described in UG835, "Vivado Design Suite
# Tcl Command Reference Guide":
# https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands
#
# Arguments (after -tclargs): <part> <source directory>
#
# The design is synthesized out of context (-mode out_of_context), i.e. as a
# module inside a larger design: No I/O buffers are inserted, and no I/O pins
# are assigned. So the timing only covers the paths between registers, with
# the clock in fast_sqrt2.xdc.
#
# The reports are written to the current directory. The build fails if the
# design does not meet timing, and the routed checkpoint post_route.dcp is
# only written if it does.

lassign $argv part src

read_vhdl -vhdl2008 [file join $src dsp.vhd]
read_vhdl -vhdl2008 [file join $src fast_sqrt2.vhd]
read_xdc -mode out_of_context [file join $src fast_sqrt2.xdc]

synth_design -top fast_sqrt2 -part $part -mode out_of_context
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
set brams [llength [get_cells -hierarchical -filter {REF_NAME =~ RAMB*}]]
puts "SUMMARY: fast_sqrt2: LUT $luts, FF $ffs, DSP $dsps, BRAM $brams,\
      worst path: slack $slack ns, [get_property LOGIC_LEVELS $path] logic levels,\
      from [get_property STARTPOINT_PIN $path] to [get_property ENDPOINT_PIN $path]"

if {$slack < 0} {
   puts "TIMING VIOLATED -- see timing_summary.rpt"
   exit 1
}

write_checkpoint -force post_route.dcp
