# CPU clock domain - 50 MHz (20ns period)
create_clock -name cpu_clk "cpu_clk" -period 20

# Network clock domain - 100 MHz (10ns period)
create_clock -name net_clk "net_clk" -period 10

# Set asynchronous clock groups
set_clock_groups -asynchronous -group {cpu_clk} -group {net_clk}
