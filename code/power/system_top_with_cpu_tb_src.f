# Source files for system_top_with_cpu testbench - Complete Neuromorphic NoC with RISC-V CPUs
# =============================================================================
# Include directories
# =============================================================================
+incdir+../cpu/fpu
+incdir+../cpu/noc
+incdir+../cpu/neuron_bank
+incdir+../cpu/cpu
+incdir+../cpu/zicsr
+incdir+../cpu

# =============================================================================
# Support Modules FIRST (needed by FPU and CPU)
# =============================================================================
../cpu/support_modules/mux_2to1_32bit.v
../cpu/support_modules/mux_2to1_3bit.v
../cpu/support_modules/mux_4to1_32bit.v
../cpu/support_modules/plus_4_adder.v

# =============================================================================
# FPU Components (IEEE 754) - WITH INCLUDE GUARDS
# =============================================================================
"../cpu/fpu/Priority Encoder.v"
../cpu/fpu/Addition-Subtraction.v
../cpu/fpu/Multiplication.v
../cpu/fpu/Division.v
../cpu/fpu/Comparison.v
../cpu/fpu/Converter.v
../cpu/fpu/Iteration.v
../cpu/fpu/fpu.v

# =============================================================================
# RISC-V CPU Components (RV32IMF) - NO INCLUDES (files standalone)
# =============================================================================
../cpu/alu/alu.v
../cpu/reg_file/reg_file.v
../cpu/f_reg_file/f_reg_file.v
../cpu/f_alu/f_alu.v
../cpu/immediate_generation_unit/immediate_generation_unit.v
../cpu/immediate_select_unit/immediate_select_unit.v
../cpu/control_unit/control_unit.v
../cpu/branch_control_unit/branch_control_unit.v
../cpu/hazard_detection_unit/hazard_detection_unit.v
../cpu/forwarding_units/ex_forward_unit.v
../cpu/forwarding_units/mem_forward_unit.v
../cpu/pipeline_flush_unit/pipeline_flush_unit.v
../cpu/zicsr/zicsr.v

# Pipeline Registers
../cpu/pipeline_registers/pr_if_id.v
../cpu/pipeline_registers/pr_id_ex.v
../cpu/pipeline_registers/pr_ex_mem.v
../cpu/pipeline_registers/pr_mem_wb.v

# CPU Top (standalone, no includes needed)
../cpu/cpu/cpu.v

# =============================================================================
# NoC Components (NO crossbar.v - it's inside router.v)
# =============================================================================
../cpu/noc/async_fifo.v
../cpu/noc/input_router.v
../cpu/noc/rr_arbiter.v
../cpu/noc/virtual_channel.v
../cpu/noc/input_module.v
../cpu/noc/output_module.v
../cpu/noc/router.v
../cpu/noc/network_interface.v

# =============================================================================
# Neuron Bank Components
# =============================================================================
../cpu/neuron_bank/rng.v
../cpu/neuron_bank/neuron_core.v
../cpu/neuron_bank/neuron_bank.v

# =============================================================================
# System Top Module (standalone, no includes)
# =============================================================================
../cpu/system_top_with_cpu.v

# =============================================================================
# Testbench
# =============================================================================
../cpu/testbench/system_top_with_cpu_tb.v
