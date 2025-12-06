# CPU Source Files for Power Analysis
# ====================================
# Main testbench
../../cpu/cpu/cpu_tb.v

# Main CPU module  
../../cpu/cpu/cpu.v

# ALU and FPU
../../cpu/alu/alu.v
../../cpu/fpu/fpu.v
../../cpu/fpu/Addition-Subtraction.v
../../cpu/fpu/Comparison.v
../../cpu/fpu/Converter.v
../../cpu/fpu/Division.v
../../cpu/fpu/Iteration.v
../../cpu/fpu/Multiplication.v
../../cpu/fpu/Priority\ Encoder.v

# Register Files
../../cpu/reg_file/reg_file.v
../../cpu/f_reg_file/f_reg_file.v

# Control Units
../../cpu/control_unit/control_unit.v
../../cpu/branch_control_unit/branch_control_unit.v
../../cpu/immediate_generation_unit/immediate_generation_unit.v
../../cpu/hazard_detection_unit/hazard_detection_unit.v
../../cpu/pipeline_flush_unit/pipeline_flush_unit.v

# Forwarding Units
../../cpu/forwarding_units/ex_forward_unit.v
../../cpu/forwarding_units/mem_forward_unit.v

# Pipeline Registers
../../cpu/pipeline_registers/pr_if_id.v
../../cpu/pipeline_registers/pr_id_ex.v
../../cpu/pipeline_registers/pr_ex_mem.v
../../cpu/pipeline_registers/pr_mem_wb.v

# Support Modules
../../cpu/support_modules/plus_4_adder.v
../../cpu/support_modules/mux_2to1_32bit.v
../../cpu/support_modules/mux_4to1_32bit.v
