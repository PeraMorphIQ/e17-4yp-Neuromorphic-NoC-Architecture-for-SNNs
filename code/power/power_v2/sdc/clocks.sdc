# CPU Clock - 50 MHz (20 ns period)
create_clock -name cpu_clk -period 20 [get_ports cpu_clk]

# Network Clock - 100 MHz (10 ns period)  
create_clock -name net_clk -period 10 [get_ports net_clk]

# Set clocks as asynchronous to each other
set_clock_groups -asynchronous -group {cpu_clk} -group {net_clk}
