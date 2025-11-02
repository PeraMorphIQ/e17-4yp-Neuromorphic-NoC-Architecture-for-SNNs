# Neuromorphic Network-on-Chip Implementation

## Overview

This directory contains the complete hardware implementation of a configurable neuromorphic Network-on-Chip architecture for Spiking Neural Networks, based on the RISC-V ISA.

## Directory Structure

```
code/cpu/
├── noc/                          # Network-on-Chip components
│   ├── async_fifo.v             # Asynchronous FIFO for clock domain crossing
│   ├── network_interface.v      # Network interface with AXI4-Lite
│   ├── input_router.v           # XY/YX routing algorithm
│   ├── virtual_channel.v        # Virtual channel FIFO buffer
│   ├── rr_arbiter.v            # Round-robin arbiter
│   ├── input_module.v          # Input module with routing and VCs
│   ├── output_module.v         # Output module with VCs and arbitration
│   └── router.v                # 5x5 crossbar router
├── neuron_bank/                 # Neuron computation units
│   ├── neuron_core.v           # Configurable neuron (Izhikevich/LIF)
│   ├── rng.v                   # Random number generator
│   └── neuron_bank.v           # Bank of neurons with CPU interface
├── control_unit/                # Modified for custom instructions
│   └── control_unit.v          # Added SWNET/LWNET support
├── noc_top.v                    # Top-level NoC integration
└── testbench/noc/               # Testbenches
    └── network_interface_tb.v   # Network interface testbench
```

## Key Features Implemented

### 1. Network-on-Chip (NoC)

- **2D Mesh Topology**: Configurable mesh size
- **XY/YX Routing**: Deterministic routing algorithms
- **Virtual Channels**: Deadlock-free routing with 4 VCs per port
- **Flow Control**: Credit-based flow control with ready/valid handshaking
- **Clock Domain Crossing**: Async FIFOs between CPU and network domains

### 2. Network Interface

- **AXI4-Lite Slave**: Standard interface for CPU communication
- **Dual FIFOs**: Separate read/write buffers with async clock crossing
- **Interrupt Generation**: Notifies CPU when packets arrive
- **Packet Format**: 32-bit packets [31:16]=RouterAddr, [15:0]=NeuronAddr

### 3. Custom RISC-V Instructions

- **SWNET (opcode 7'b0101111)**: Store word to network
  - S-Type format: `SWNET rs2, offset(rs1)`
  - Sends spike information to network interface
- **LWNET (opcode 7'b0101011)**: Load word from network
  - I-Type format: `LWNET rd, offset(rs1)`
  - Reads spike packets from network interface
  - Called from ISR when interrupt occurs

### 4. Neuron Banks

- **Configurable Neuron Cores**: Support both Izhikevich and LIF models
- **Hardware Acceleration**: Dedicated floating-point units for neuron updates
- **CPU-Addressable Registers**: Memory-mapped configuration and control
- **RNG Integration**: LFSR-based random number generation
- **Spike Detection**: Hardware-level spike threshold checking

### 5. Neuron Models

#### Leaky Integrate-and-Fire (LIF)

```
v' = av + bI
if v >= v_th: v = v - v_th
```

#### Izhikevich

```
v' = 0.04v² + 5v + 140 - u + I
u' = a(bv - u)
if v >= v_th: v = c, u = u + d
```

## Configuration Parameters

### NoC Configuration

```verilog
MESH_SIZE_X = 2              // Nodes in X dimension
MESH_SIZE_Y = 2              // Nodes in Y dimension
ROUTER_ADDR_WIDTH = 8        // Router address bits
VC_DEPTH = 4                 // Virtual channel depth
ROUTING_ALGORITHM = 0        // 0=XY, 1=YX
```

### Neuron Bank Configuration

```verilog
NUM_NEURONS_PER_BANK = 4     // Neurons per bank
```

## Memory Map

### Network Interface

- Write to any address: Sends packet to network (SWNET)
- Read from any address: Receives packet from network (LWNET)

### Neuron Bank Registers (per neuron, offset by 8 bytes)

```
Base + 0x00: Neuron type (0=LIF, 1=Izhikevich)
Base + 0x01: Threshold voltage (v_th)
Base + 0x02: Parameter a
Base + 0x03: Parameter b
Base + 0x04: Parameter c
Base + 0x05: Parameter d
Base + 0x06: Control register (start update)
Base + 0x07: Status register (spike/busy)

Input buffers:
0x80-0x83: Neuron 0 input
0x84-0x87: Neuron 1 input
...

Special registers:
0xC0: RNG seed
0xC1: RNG output
0xC2: Spike status (all neurons)
```

## Interrupt Mechanism

The custom interrupt mechanism uses ZiCSR registers:

- **MSCRATCH (0x340)**: Stores PC during interrupt
- **MTVEC (0x305)**: ISR address
- **Interrupt source**: Network interface read FIFO not empty

Interrupt FSM States:

1. IDLE: Normal CPU operation
2. ISR_INIT: Save PC to MSCRATCH
3. ISR_LOAD: Load ISR address from MTVEC
4. ISR: Execute interrupt service routine
5. RETURN: Restore PC from MSCRATCH

## Building and Testing

### Simulation with iverilog

```bash
# Compile network interface testbench
iverilog -o network_interface_tb \
  noc/async_fifo.v \
  noc/network_interface.v \
  testbench/noc/network_interface_tb.v

# Run simulation
vvp network_interface_tb

# View waveforms
gtkwave network_interface_tb.vcd
```

### Synthesis for FPGA

The design is targeted for Intel Cyclone IV E FPGA. See `fpga/` directory for synthesis scripts.

## Usage Example

### Initializing a Neuron

```c
// Configure neuron 0 as Izhikevich
volatile uint32_t *neuron_bank = (uint32_t *)0x10000000;
neuron_bank[0] = 1;           // Type: Izhikevich
neuron_bank[1] = 0x41200000;  // v_th = 10.0
neuron_bank[2] = 0x3D23D70A;  // a = 0.04
neuron_bank[3] = 0x40A00000;  // b = 5.0
neuron_bank[4] = 0xC2140000;  // c = -65.0
neuron_bank[5] = 0x40000000;  // d = 2.0
```

### Sending a Spike via Network

```assembly
# SWNET: Send spike to router [0,1], neuron 5
li t0, 0x00010005        # Packet: router=0x0001, neuron=0x0005
li t1, 0x20000000        # Network interface address
SWNET t0, 0(t1)          # Custom instruction
```

### Receiving a Spike (in ISR)

```assembly
spike_isr:
    # Save context
    csrw mscratch, ra

    # Read spike from network
    li t1, 0x20000000        # Network interface address
    LWNET t0, 0(t1)          # Custom instruction

    # Process spike (update neuron inputs)
    # ... spike handling code ...

    # Return from interrupt
    csrr ra, mscratch
    ret
```

## Performance Characteristics

Based on experiments with 4-neuron fully-connected SNN:

| Configuration             | Init Cycles | Per-Step Cycles |
| ------------------------- | ----------- | --------------- |
| Single Core               | 105         | 331             |
| 2-Core NoC                | 105         | 179             |
| 2-Core NoC + Neuron Banks | 115         | 146             |

**Speedup**: ~2.3x for 2-core NoC with neuron banks vs single core

## Testing and Verification

### Comprehensive Test Suite

This implementation includes a complete verification suite with testbenches for:

- **Router**: Tests XY routing, arbitration, backpressure
- **Neuron Core**: Tests both LIF and Izhikevich models with IEEE 754 FPU
- **Full Mesh**: Tests 2×2 mesh with multi-hop routing
- **Network Interface**: Tests AXI4-Lite and clock domain crossing

**See [TESTING_GUIDE.md](TESTING_GUIDE.md) for detailed testing procedures.**

### Running Tests

```bash
# Run all tests
make -f Makefile_noc_tests all

# Run individual tests
make -f Makefile_noc_tests router
make -f Makefile_noc_tests neuron
make -f Makefile_noc_tests mesh

# View waveforms
make -f Makefile_noc_tests router_wave
```

### IEEE 754 FPU Integration

The neuron core now uses proper IEEE 754 floating-point arithmetic:

- ✅ **Addition_Subtraction.v**: For addition and subtraction operations
- ✅ **Multiplication.v**: For multiplication operations
- ✅ **Exception Handling**: Overflow, underflow, NaN detection
- ✅ **Synthesizable**: Ready for FPGA implementation

**See [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) for details on FPU integration.**

## Additional Documentation

- **TESTING_GUIDE.md**: Comprehensive testing procedures and verification methodology
- **IMPLEMENTATION_SUMMARY.md**: Review of implementation, improvements, and performance analysis
- **Makefile_noc_tests**: Automated build and test system

## Future Enhancements

1. **Full CPU Integration**: Complete connection of CPU with network interface via memory controller
2. **Memory Arbitration**: Add proper arbiter for shared memory access
3. **Advanced Routing**: Implement adaptive routing algorithms
4. **Power Management**: Add clock gating and power domains
5. **Fault Tolerance**: Implement error detection and correction
6. **Larger Mesh**: Scale to 4×4 or 8×8 topologies

## References

1. Research Paper: "Configurable Neuromorphic Network-on-Chip Architecture for Spiking Neural Networks"
2. RISC-V ISA Specification: https://riscv.org/specifications/
3. AXI4 Protocol Specification: ARM IHI 0022E
4. Izhikevich, E.M. (2003). "Simple model of spiking neurons"

## Authors

- E/17/018, Balasuriya I.S.
- E/17/154, Karunanayake A.I.
- E/17/286, Rathnayaka R.M.T.N.K.

## License

This project is part of a final year project at University of Peradeniya.
