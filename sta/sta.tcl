# sta.tcl -- OpenSTA setup-timing analysis of the synthesized mult_array netlist
# Typical corner only (tt_025C_1v80).
# Run from the repository root:   sta sta/sta.tcl
# The clock period T (ns) can be set with the environment variable CLK_PERIOD.
#   Run 1:  CLK_PERIOD=10 sta sta/sta.tcl  -> WNS = 7.396 ns -> Tmin = 10 - 7.396 = 2.604 ns
#   Run 2:  sta sta/sta.tcl                -> T = Tmin rounded up to 0.01 ns = 2.61 ns, slack +0.006 ns
# The default below is the final run, which produces sta/mult_array_timing.rpt.

if {[info exists ::env(PDK_ROOT)]} {
    set pdk_root $::env(PDK_ROOT)
} else {
    set pdk_root $::env(HOME)/.ciel
}
set lib $pdk_root/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

if {[info exists ::env(CLK_PERIOD)]} {
    set T $::env(CLK_PERIOD)
} else {
    set T 2.61
}
puts "Clock period T = $T ns"

# 1. Read the cell timing library
read_liberty $lib

# 2. Read and link the netlist
read_verilog synth/mult_array_netlist.v
link_design mult_array

# 3. Define the clock with period T (ns)
create_clock -name clk -period $T [get_ports clk]

# 4. Input arrival time
set_input_delay 1.0 -clock clk [delete_from_list [all_inputs] [get_ports clk]]

# 5. Output required time
set_output_delay 1.0 -clock clk [all_outputs]

# 6. Print the worst setup slack
report_worst_slack -max

# 7. Save the critical path report
report_checks -path_delay max -digits 3 > sta/mult_array_timing.rpt

exit
