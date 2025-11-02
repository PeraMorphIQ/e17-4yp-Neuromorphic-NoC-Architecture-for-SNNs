# =============================================================================
# Clock Constraints for System Top - 2x2 Mesh NoC with Neuron Banks
# =============================================================================
# System Top has dual clock domains:
#   - cpu_clk: 50 MHz (20 ns period) - External control interface and neuron banks
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

# Input delays (assuming external signals arrive mid-cycle relative to cpu_clk)
set_input_delay -clock cpu_clk -max 10.0 [get_ports {node_select[*] address[*] write_enable read_enable write_data[*]}]
set_input_delay -clock cpu_clk -min 2.0 [get_ports {node_select[*] address[*] write_enable read_enable write_data[*]}]

# Output delays (assuming external logic samples mid-cycle relative to cpu_clk)
set_output_delay -clock cpu_clk -max 10.0 [get_ports {read_data[*] ready interrupt[*] spike_out[*]}]
set_output_delay -clock cpu_clk -min 2.0 [get_ports {read_data[*] ready interrupt[*] spike_out[*]}]

# Reset is asynchronous - no timing constraints needed
set_false_path -from [get_ports rst_n]

# Load constraints (assuming moderate fanout)
set_load 0.05 [all_outputs]

# Drive strength (assuming standard drive from external controller)
set_drive 1.0 [all_inputs]
