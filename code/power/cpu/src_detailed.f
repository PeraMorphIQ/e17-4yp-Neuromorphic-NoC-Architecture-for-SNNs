# CPU Source Files for Power Analysis
# ====================================
# Main CPU module (includes all submodules via `include statements)
cpu/cpu.v

# Note: cpu.v includes all submodules (alu, fpu, reg_file, control units, etc.)
# through `include statements, so we don't need to list them individually.
# For simulation with testbench, VCS uses this file along with cpu_tb.v
