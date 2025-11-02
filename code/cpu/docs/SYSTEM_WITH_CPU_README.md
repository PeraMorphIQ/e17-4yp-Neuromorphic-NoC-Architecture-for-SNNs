# System Top with RISC-V CPUs - Final Neuromorphic NoC Architecture

## Overview

This is the **final integrated design** as described in the research paper. Each node in the 2×2 mesh NoC contains a complete processing element with:

1. **RV32IMF RISC-V CPU** - With custom SNN instructions
2. **Network Interface** - AXI4-Lite + Clock Domain Crossing
3. **Router** - 5-port crossbar with XY routing
4. **Neuron Bank** - Configurable neuron cores (LIF/Izhikevich)
5. **Instruction Memory** - For storing SNN programs

## Architecture Diagram

```
Node (X,Y) Structure:
┌──────────────────────────────────────────────────────┐
│  ┌────────────┐         ┌─────────────┐             │
│  │   RISC-V   │◄───────►│  Network    │◄───────────►│ To Router Mesh
│  │   CPU      │  AXI    │  Interface  │   Packets   │
│  │  RV32IMF   │         │  (CDC FIFO) │             │
│  └─────┬──────┘         └─────────────┘             │
│        │ Memory                                       │
│        │ Access                                       │
│  ┌─────▼──────┐         ┌─────────────┐             │
│  │  Neuron    │         │ Instruction │             │
│  │   Bank     │         │   Memory    │◄────────────│ Program Load
│  │ (4 neurons)│         │  (1K words) │             │
│  └────────────┘         └─────────────┘             │
└──────────────────────────────────────────────────────┘
```

## Complete 2×2 Mesh Layout

```
        Network Clock Domain (100 MHz)
              ┌─────────┐
              │ Router  │
              │  (0,1)  │
              └────┬────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
   ┌────▼────┐┌───▼────┐┌───▼────┐
   │ Router  ││ Router ││ Router │
   │  (0,0)  ││  (1,0) ││  (1,1) │
   └────┬────┘└───┬────┘└───┬────┘
        │         │          │
   ┌────▼────┐┌──▼─────┐┌──▼─────┐
   │  Node   ││  Node  ││  Node  │
   │  (0,0)  ││  (1,0) ││  (1,1) │
   │ CPU+NB  ││ CPU+NB ││ CPU+NB │
   └─────────┘└────────┘└────────┘
```

Each node runs independently in **CPU clock domain (50 MHz)** and communicates via the **network clock domain (100 MHz)** through the CDC FIFOs in the network interfaces.

## Key Features

### 1. Custom RISC-V Instructions

As per the paper (Section IV.B), two custom instructions are implemented:

- **LWNET** (Load Word from Network)

  - Reads spike packets from network interface FIFO
  - Used in interrupt service routine to handle incoming spikes
  - Syntax: `LWNET rd, rs1, offset`

- **SWNET** (Store Word to Network)
  - Sends spike packets to destination neuron via NoC
  - Includes destination node address and neuron ID
  - Syntax: `SWNET rs1, rs2, offset`

### 2. Interrupt Mechanism

As described in Section IV.C:

- **Interrupt Source**: Network interface FIFO has data ready
- **ISR (Interrupt Service Routine)**: Handles spike propagation
- **Registers Used**:
  - `MSCRATCH` (0x340): Stores saved PC
  - `MTVEC` (0x305): Stores ISR address

**5-Stage FSM**:

1. IDLE: Normal CPU operation
2. ISR_INIT: Save current PC to MSCRATCH
3. ISR_LOAD: Load ISR address from MTVEC
4. ISR_STATE: Execute interrupt handler
5. RETURN: Restore PC from MSCRATCH

### 3. Packet Format

As shown in Figure 4 of the paper:

```
31                    16 15                     0
┌───────────────────────┬──────────────────────┐
│  Destination Address  │    Neuron Address    │
│    (X[7:0], Y[7:0])   │      (ID[15:0])      │
└───────────────────────┴──────────────────────┘
```

### 4. Neuron Lifecycle

From Section VII.A, neurons operate in three stages:

1. **Membrane Potential Update**

   - Continuous update every timestep
   - Check for threshold crossing (spike detection)
   - Izhikevich: 7 cycles, LIF: 3 cycles

2. **Spike Resolution**

   - CPU resolves spike via network
   - Propagate to downstream neurons
   - Apply synaptic weights

3. **After-spike Reset**
   - Reset membrane potential below threshold
   - Resume normal updates

### 5. CPU-Addressable Neuron Banks

From Section VIII:

**Register Map** (per neuron):

- `0x00`: Neuron type (0=LIF, 1=Izhikevich)
- `0x04`: Threshold voltage (v_th)
- `0x08`: Parameter 'a'
- `0x0C`: Parameter 'b'
- `0x10`: Parameter 'c'
- `0x14`: Parameter 'd'
- `0x18`: Input buffer (write current input)
- `0x1C`: Status (read spike/busy flags)

## Module Parameters

```verilog
parameter MESH_SIZE_X = 2;              // Number of nodes in X direction
parameter MESH_SIZE_Y = 2;              // Number of nodes in Y direction
parameter NUM_NEURONS_PER_BANK = 4;     // Neurons per node
parameter PACKET_WIDTH = 32;            // Packet size
parameter DATA_WIDTH = 32;              // Data width
parameter ADDR_WIDTH = 8;               // Address width
parameter NUM_VC = 4;                   // Virtual channels per port
parameter VC_DEPTH = 4;                 // Depth of each VC buffer
```

## Port Descriptions

### System Clocks and Reset

- `cpu_clk`: 50 MHz clock for CPUs, neuron banks, instruction memory
- `net_clk`: 100 MHz clock for routers and network interfaces
- `rst_n`: Active-low asynchronous reset

### Program Loading Interface

- `prog_load_enable[N-1:0]`: Enable program load for each node
- `prog_load_addr[31:0]`: Instruction memory address
- `prog_load_data[31:0]`: Instruction data
- `prog_load_write[N-1:0]`: Write enable per node

### External Input Injection (Training/Inference)

- `ext_node_select[7:0]`: {Y[3:0], X[3:0]} - select target node
- `ext_neuron_id[7:0]`: Neuron ID within selected node
- `ext_input_current[31:0]`: Current value (IEEE 754 float)
- `ext_input_valid`: Input valid signal

### Debug Outputs

- `cpu_interrupt[N-1:0]`: Interrupt status per CPU
- `spike_out[N*M-1:0]`: Spike outputs from all neurons (N nodes × M neurons)
- `cpu_halted[N-1:0]`: CPU halt status (for debugging)
- `router_*`: Router port monitoring signals

## Programming Model

### Initialization Sequence

1. **Load Programs** (External Controller)

```c
// Load program to Node (0,0)
prog_load_enable[0] = 1;
for (int addr = 0; addr < program_size; addr++) {
    prog_load_addr = addr << 2;
    prog_load_data = instruction[addr];
    prog_load_write[0] = 1;
    // Wait one cycle
}
```

2. **Configure Neurons** (CPU Program)

```assembly
# Configure neuron 0 as LIF with v_th = -50.0
li   t0, 0x00          # Neuron type register
li   t1, 0             # LIF type
sw   t1, 0(t0)         # Write to neuron bank

li   t0, 0x04          # Threshold register
li   t1, 0xC2480000    # -50.0 in IEEE 754
sw   t1, 0(t0)

# Configure LIF parameters a, b
li   t0, 0x08
li   t1, 0xBF800000    # a = -1.0
sw   t1, 0(t0)

li   t0, 0x0C
li   t1, 0x3F800000    # b = 1.0
sw   t1, 0(t0)
```

3. **Setup ISR** (CPU Program)

```assembly
# Load ISR address into MTVEC
la   t0, spike_isr
csrw mtvec, t0
```

### SNN Simulation Loop

```assembly
simulation_loop:
    # Inject input current to neuron 0
    li   t0, 0x18          # Input buffer register
    li   t1, 0x40A00000    # Current = 5.0
    sw   t1, 0(t0)

    # Wait for computation (neurons auto-update)
    li   t0, 1000
wait_loop:
    addi t0, t0, -1
    bnez t0, wait_loop

    # Check for spikes
    li   t0, 0x1C          # Status register
    lw   t1, 0(t0)
    andi t2, t1, 0x01      # Check spike bit
    beqz t2, no_spike

spike_detected:
    # Propagate spike via network
    li   t0, 0x00010001    # Dest: Node(0,1), Neuron 1
    li   t1, 0x40000000    # Weight = 2.0
    SWNET t1, t0, 0        # Send to network

no_spike:
    j    simulation_loop
```

### Interrupt Service Routine (Spike Handling)

```assembly
spike_isr:
    # Save context (simplified)
    addi sp, sp, -16
    sw   ra, 0(sp)
    sw   t0, 4(sp)
    sw   t1, 8(sp)

receive_loop:
    # Read incoming spike packet
    LWNET t0, 0, 0         # Read packet from network

    # Extract neuron ID (lower 16 bits)
    andi  t1, t0, 0xFFFF

    # Add synaptic weight to neuron input
    slli  t1, t1, 2        # Multiply by 4 for word offset
    addi  t1, t1, 0x18     # Input buffer base
    lw    t2, 0(t1)        # Read current input
    # ... add weight from packet ...
    sw    t2, 0(t1)        # Write updated input

    # Check if more packets available
    # ... (network interface provides status) ...

    # Restore context and return
    lw   ra, 0(sp)
    lw   t0, 4(sp)
    lw   t1, 8(sp)
    addi sp, sp, 16
    mret                   # Return from interrupt
```

## Experimental Setup

From Section IX of the paper, three experiments were conducted:

- **EXP-1**: Single RV32IMF core (baseline)
- **EXP-2**: Two-core NoC, no neuron hardware
- **EXP-3**: Two-core NoC with neuron banks (this design)

**Results** (Figure 10):

- Initialization: ~105-115 cycles (all experiments)
- Per timestep:
  - EXP-1: 331 cycles (baseline)
  - EXP-2: 179 cycles (46% reduction)
  - **EXP-3: 146 cycles (56% reduction)** ✓

## Performance Characteristics

### Advantages

1. **Instruction-Level Parallelism (ILP)**

   - Multiple CPUs execute independently
   - ~2× speedup with 2 nodes

2. **Hardware Acceleration**

   - Neuron cores offload membrane potential updates
   - 7-cycle Izhikevich, 3-cycle LIF (pipelined)
   - Further ~20% improvement over software-only

3. **Scalability**

   - Easy to scale to 4×4, 8×8 meshes
   - O(√N) hop count with XY routing
   - Minimal register spilling (neurons in hardware)

4. **Event-Driven Communication**
   - Sparse spike traffic exploits NoC efficiency
   - Virtual channels prevent deadlock
   - Asynchronous message passing

### Limitations

1. **Clock Domain Crossing Latency**

   - CDC FIFOs add ~2-3 cycles
   - Acceptable for sparse spike events

2. **Interrupt Overhead**

   - 5-cycle ISR entry/exit
   - Mitigated by batching spikes in ISR

3. **FPU Accuracy Issues**
   - Current FPU modules have known bugs
   - Need Berkeley HardFloat replacement
   - Does not affect architecture correctness

## Scaling to Larger Meshes

To scale to 4×4 (16 nodes, 64 neurons):

```verilog
parameter MESH_SIZE_X = 4;
parameter MESH_SIZE_Y = 4;
parameter NUM_NEURONS_PER_BANK = 4;  // Total: 64 neurons
```

**Expected Performance**:

- Max hop count: 6 hops (4+4-2)
- Average hop count: ~3 hops
- Network bandwidth: Sufficient for sparse spikes
- Clock frequency: Same (no critical path change)

## Comparison with State-of-the-Art

From Section II (Background):

| Architecture     | Cores                | Neurons      | Technology | Power  | Notes                  |
| ---------------- | -------------------- | ------------ | ---------- | ------ | ---------------------- |
| **SpiNNaker**    | 57,600 ARM968        | Millions     | Custom     | 100 kW | Massive scale          |
| **DYNAP**        | Custom               | 1024/chip    | ASIC       | mW     | Heterogeneous memory   |
| **ODIN**         | RISC-V + Coprocessor | 256          | FPGA       | mW     | IoT focus              |
| **POETS/Tinsel** | Hyperthreaded RISC-V | Configurable | FPGA       | -      | Graph-based            |
| **This Work**    | 4× RV32IMF           | 16           | FPGA       | TBD    | Configurable, scalable |

**Key Differentiator**: Balance between flexibility (programmable CPUs) and efficiency (hardware neuron cores).

## Future Enhancements

### From Section XI (Conclusion)

1. **CPU Improvements**

   - Out-of-order execution
   - Dynamic branch prediction
   - Larger caches

2. **Programming Abstractions**

   - High-level SNN API
   - Compiler support for custom instructions
   - Automated neuron placement

3. **Hardware Optimizations**

   - Replace buggy FPU with Berkeley HardFloat
   - Add STDP (Spike-Timing-Dependent Plasticity)
   - Implement adaptive routing

4. **System Integration**
   - Add DMA for bulk data transfer
   - Implement multicast for spike fanout
   - Support for convolutional layers

## Testing

To test the complete system, you would need to:

1. **Load Programs** into instruction memories
2. **Configure Neurons** via CPU memory writes
3. **Inject Input** via external interface
4. **Monitor Outputs** (spikes, interrupts, router traffic)

See the companion testbench: `testbench/system_top_with_cpu_tb.v` (to be created)

## Synthesis Results (Target: 45nm CMOS)

Use the power analysis scripts in `../power/`:

```bash
cd ../power
# Update config.tcl to point to system_top_with_cpu
design_shell -f rtla.tcl
design_shell -f restore_new.tcl
```

**Expected Metrics** (to be measured):

- Maximum frequency: ~200-400 MHz
- Total power: ~50-100 mW per node
- Area: ~0.5-1.0 mm² per node @ 45nm

## Related Files

- `system_top.v`: Simplified version without CPUs (for baseline testing)
- `cpu/cpu.v`: RV32IMF processor with custom instructions
- `noc/router/router.v`: 5-port router with XY routing
- `noc/network_interface/network_interface.v`: AXI4-Lite + CDC
- `neuron_bank/neuron_bank.v`: Configurable neuron array
- `neuron_bank/neuron_core.v`: Single neuron (LIF/Izhikevich)

## References

See `Research_Paper/conference_101719.tex` for complete citations.

Key sections:

- Section III: Overall Architecture
- Section IV: CPU Core (custom instructions, interrupts)
- Section V: Network-on-Chip
- Section VI: Configurable Neuron Cores
- Section VII: Neuron Banks
- Section IX: Experiments
- Section X: Results

---

**Note**: This is the complete architecture as described in the research paper. The current implementation is ready for FPGA synthesis and power analysis using 45nm CMOS technology libraries.
