# CPU Source Files for Power Analysis
# ====================================
# Main testbench
cpu/cpu_tb.v

# Main CPU module  
cpu/cpu.v

# ALU and FPU
alu/alu.v
fpu/fpu.v
# Note: fpu.v includes all other FPU files via `include statements

# Register Files
reg_file/reg_file.v
f_reg_file/f_reg_file.v

# Control Units
control_unit/control_unit.v
branch_control_unit/branch_control_unit.v
immediate_generation_unit/immediate_generation_unit.v
hazard_detection_unit/hazard_detection_unit.v
pipeline_flush_unit/pipeline_flush_unit.v

# Forwarding Units
forwarding_units/ex_forward_unit.v
forwarding_units/mem_forward_unit.v

# Pipeline Registers
pipeline_registers/pr_if_id.v
pipeline_registers/pr_id_ex.v
pipeline_registers/pr_ex_mem.v
pipeline_registers/pr_mem_wb.v

# Support Modules
support_modules/plus_4_adder.v
support_modules/mux_2to1_32bit.v
support_modules/mux_4to1_32bit.v
