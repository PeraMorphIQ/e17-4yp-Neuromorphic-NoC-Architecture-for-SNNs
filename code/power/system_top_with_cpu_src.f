# Source files for system_top_with_cpu design - Complete Neuromorphic NoC with RISC-V CPUs
# =============================================================================
# Top-level integration module with CPUs
# =============================================================================
../cpu/system_top_with_cpu.v

# =============================================================================
# RISC-V CPU Components (RV32IMF)
# =============================================================================
../cpu/cpu/cpu.v
../cpu/cpu/control_unit.v
../cpu/alu/alu.v
../cpu/reg_file/reg_file.v
../cpu/f_reg_file/f_reg_file.v
../cpu/f_alu/f_alu.v
../cpu/immediate_generation_unit/immediate_generation_unit.v
../cpu/immediate_select_unit/immediate_select_unit.v
../cpu/branch_control_unit/branch_control_unit.v
../cpu/hazard_detection_unit/hazard_detection_unit.v
../cpu/forwarding_units/ex_forward_unit.v
../cpu/forwarding_units/mem_forward_unit.v
../cpu/pipeline_flush_unit/pipeline_flush_unit.v

# Pipeline Registers
../cpu/pipeline_registers/pr_if_id.v
../cpu/pipeline_registers/pr_id_ex.v
../cpu/pipeline_registers/pr_ex_mem.v
../cpu/pipeline_registers/pr_mem_wb.v

# Control and Status Registers (Zicsr)
../cpu/zicsr/zicsr.v
../cpu/zicsr/rv32i_header.vh

# Support Modules
../cpu/support_modules/mux_2to1_32bit.v
../cpu/support_modules/mux_2to1_3bit.v
../cpu/support_modules/mux_4to1_32bit.v
../cpu/support_modules/plus_4_adder.v

# =============================================================================
# NoC Components - Router
# =============================================================================
../cpu/noc/router/router.v
../cpu/noc/router/input_port.v
../cpu/noc/router/output_port.v
../cpu/noc/router/vc_allocator.v
../cpu/noc/router/switch_allocator.v
../cpu/noc/router/crossbar_5x5.v
../cpu/noc/router/routing_computation.v
../cpu/noc/router/rr_arbiter.v

# =============================================================================
# NoC Components - Network Interface
# =============================================================================
../cpu/noc/network_interface/network_interface.v
../cpu/noc/network_interface/axi_to_noc.v
../cpu/noc/network_interface/noc_to_axi.v
../cpu/noc/network_interface/cdc_fifo.v

# =============================================================================
# Neuron Bank Components
# =============================================================================
../cpu/neuron_bank/neuron_bank.v
../cpu/neuron_bank/neuron_core.v
../cpu/neuron_bank/rng.v

# =============================================================================
# FPU Components (IEEE 754)
# =============================================================================
../cpu/fpu/fpu.v
../cpu/fpu/Addition-Subtraction.v
../cpu/fpu/Multiplication.v
../cpu/fpu/Division.v
../cpu/fpu/Comparison.v
../cpu/fpu/Converter.v
../cpu/fpu/Iteration.v
../cpu/fpu/Priority Encoder.v

# =============================================================================
# Instruction Memory
# =============================================================================
../cpu/instruction_memory/instruction_memory.v

# =============================================================================
# Clock Divider (for debug)
# =============================================================================
../cpu/debug/clock_divider/clock_divider.v
