# =============================================================================
# Clock Constraints for System Top with CPUs - 2x2 Mesh NoC with RV32IMF CPUs
# =============================================================================
# System Top with CPUs has dual clock domains:
#   - cpu_clk: 50 MHz (20 ns period) - RISC-V CPUs and neuron banks
#   - net_clk: 100 MHz (10 ns period) - NoC router mesh and network interfaces
# =============================================================================

# CPU Clock Domain - 50 MHz (20 ns period)
create_clock -name cpu_clk -period 20.0 [get_ports cpu_clk]
set_clock_uncertainty 0.5 [get_clocks cpu_clk]
set_clock_transition 0.1 [get_clocks cpu_clk]

# Network Clock Domain - 100 MHz (10 ns period)  
create_clock -name net_clk -period 10.0 [get_ports net_clk]
set_clock_uncertainty 0.3 [get_clocks net_clk]
set_clock_transition 0.1 [get_clocks net_clk]

# Mark clocks as asynchronous (they are independent clock domains)
set_clock_groups -asynchronous \
    -group [get_clocks cpu_clk] \
    -group [get_clocks net_clk]

# Input delays for program loading interface (relative to cpu_clk)
set_input_delay -clock cpu_clk -max 10.0 [get_ports {prog_load_enable[*] prog_load_addr[*] prog_load_data[*] prog_load_write[*]}]
set_input_delay -clock cpu_clk -min 2.0 [get_ports {prog_load_enable[*] prog_load_addr[*] prog_load_data[*] prog_load_write[*]}]

# Input delays for external injection interface (relative to cpu_clk)
set_input_delay -clock cpu_clk -max 10.0 [get_ports {ext_node_select[*] ext_neuron_id[*] ext_input_current[*] ext_input_valid}]
set_input_delay -clock cpu_clk -min 2.0 [get_ports {ext_node_select[*] ext_neuron_id[*] ext_input_current[*] ext_input_valid}]

# Output delays for debug and monitoring signals (relative to cpu_clk)
set_output_delay -clock cpu_clk -max 10.0 [get_ports {cpu_interrupt[*] spike_out[*]}]
set_output_delay -clock cpu_clk -min 2.0 [get_ports {cpu_interrupt[*] spike_out[*]}]

# Output delays for router debug signals (relative to net_clk)
set_output_delay -clock net_clk -max 5.0 [get_ports {router_input_valid[*] router_input_ready[*] router_output_valid[*] router_output_ready[*]}]
set_output_delay -clock net_clk -min 1.0 [get_ports {router_input_valid[*] router_input_ready[*] router_output_valid[*] router_output_ready[*]}]

# Reset is asynchronous - no timing constraints needed
set_false_path -from [get_ports rst_n]

# Load constraints (assuming moderate fanout for multi-node system)
set_load 0.05 [all_outputs]

# Drive strength (assuming standard drive from external controller)
set_drive 1.0 [all_inputs]

# Clock domain crossing paths (if any synchronizers exist)
# Note: The design uses dual-clock FIFOs and synchronizers for CDC
# These paths should be properly constrained or marked as false paths
# Uncomment if specific CDC paths need to be constrained:
# set_false_path -from [get_clocks cpu_clk] -to [get_clocks net_clk]
# set_false_path -from [get_clocks net_clk] -to [get_clocks cpu_clk]
