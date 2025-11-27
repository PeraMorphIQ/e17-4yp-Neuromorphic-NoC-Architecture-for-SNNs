// FPU files
../../accelerator/cpu_core/fpu/Addition-Subtraction.v
../../accelerator/cpu_core/fpu/Priority Encoder.v
../../accelerator/cpu_core/fpu/Multiplication.v
../../accelerator/cpu_core/fpu/Iteration.v
../../accelerator/cpu_core/fpu/Division.v
../../accelerator/cpu_core/fpu/Converter.v
../../accelerator/cpu_core/fpu/Comparison.v
../../accelerator/cpu_core/fpu/fpu.v

// Support modules
../../accelerator/cpu_core/support_modules/mux_2to1_32bit.v
../../accelerator/cpu_core/support_modules/mux_2to1_3bit.v
../../accelerator/cpu_core/support_modules/mux_4to1_32bit.v
../../accelerator/cpu_core/support_modules/plus_4_adder.v

// Pipeline registers
../../accelerator/cpu_core/pipeline_registers/pr_if_id.v
../../accelerator/cpu_core/pipeline_registers/pr_id_ex.v
../../accelerator/cpu_core/pipeline_registers/pr_ex_mem.v
../../accelerator/cpu_core/pipeline_registers/pr_mem_wb.v

// Core units
../../accelerator/cpu_core/alu/alu.v
../../accelerator/cpu_core/branch_control_unit/branch_control_unit.v
../../accelerator/cpu_core/control_unit/control_unit.v
../../accelerator/cpu_core/data_memory/data_memory.v
../../accelerator/cpu_core/f_alu/f_alu.v
../../accelerator/cpu_core/f_reg_file/f_reg_file.v
../../accelerator/cpu_core/forwarding_units/ex_forward_unit.v
../../accelerator/cpu_core/forwarding_units/mem_forward_unit.v
../../accelerator/cpu_core/hazard_detection_unit/hazard_detection_unit.v
../../accelerator/cpu_core/immediate_generation_unit/immediate_generation_unit.v
../../accelerator/cpu_core/immediate_select_unit/immediate_select_unit.v
../../accelerator/cpu_core/instruction_memory/instruction_memory.v
../../accelerator/cpu_core/pipeline_flush_unit/pipeline_flush_unit.v
../../accelerator/cpu_core/reg_file/reg_file.v
../../accelerator/cpu_core/zicsr/zicsr.v

// CPU
../../accelerator/cpu_core/cpu/cpu.v

// Network components
../../accelerator/network_interface/fifo.v
../../accelerator/network_interface/network_interface.v
../../accelerator/router/router.v
../../accelerator/neuron_core/neuron_core.v
../../accelerator/neuron_bank/neuron_bank.v

// Node and mesh
../../accelerator/node/node.v
../../accelerator/mesh/mesh.v
