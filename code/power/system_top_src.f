# =============================================================================
# Source files for system_top design - 2x2 Mesh NoC with Neuron Banks
# =============================================================================
# Status: VERIFIED & TESTED - ALL 6 TESTS PASSING (100%)
# Description: Complete neuromorphic NoC system with routers, network interfaces,
#              neuron banks, and FPU computation
# =============================================================================

# Top-level integration module
../cpu/system_top.v

# =============================================================================
# NoC Components (actual file structure - no subdirectories)
# =============================================================================
../cpu/noc/router.v
../cpu/noc/input_module.v
../cpu/noc/output_module.v
../cpu/noc/input_router.v
../cpu/noc/virtual_channel.v
../cpu/noc/rr_arbiter.v
../cpu/noc/network_interface.v
../cpu/noc/async_fifo.v

# =============================================================================
# Neuron Bank Components
# =============================================================================
../cpu/neuron_bank/neuron_bank.v
../cpu/neuron_bank/neuron_core.v
../cpu/neuron_bank/rng.v

# =============================================================================
# FPU Components (IEEE 754 with include guards)
# =============================================================================
../cpu/fpu/fpu.v
../cpu/fpu/Addition-Subtraction.v
../cpu/fpu/Multiplication.v
../cpu/fpu/Division.v
../cpu/fpu/Comparison.v
../cpu/fpu/Converter.v
../cpu/fpu/Iteration.v
"../cpu/fpu/Priority Encoder.v"

# =============================================================================
# Instruction Memory
# =============================================================================
../cpu/instruction_memory/instruction_memory.v

# Include directories for headers
+incdir+../cpu/fpu
+incdir+../cpu/noc
+incdir+../cpu/neuron_bank
