# Source files for system_top design - Neuromorphic NoC with 2x2 Mesh
# Top-level integration module
../cpu/system_top.v

# NoC Components - Router
../cpu/noc/router/router.v
../cpu/noc/router/input_port.v
../cpu/noc/router/output_port.v
../cpu/noc/router/vc_allocator.v
../cpu/noc/router/switch_allocator.v
../cpu/noc/router/crossbar_5x5.v
../cpu/noc/router/routing_computation.v
../cpu/noc/router/rr_arbiter.v

# NoC Components - Network Interface
../cpu/noc/network_interface/network_interface.v
../cpu/noc/network_interface/axi_to_noc.v
../cpu/noc/network_interface/noc_to_axi.v
../cpu/noc/network_interface/cdc_fifo.v

# Neuron Bank Components
../cpu/neuron_bank/neuron_bank.v
../cpu/neuron_bank/neuron_core.v
../cpu/neuron_bank/rng.v

# FPU Components
../cpu/fpu/Addition-Subtraction.v
../cpu/fpu/Multiplication.v

# Instruction Memory (used by neuron_bank)
../cpu/instruction_memory/instruction_memory.v
