# System Top Module Documentation

## Overview

The `system_top.v` module represents the complete neuromorphic Network-on-Chip (NoC) system, integrating all components into a fully functional system. This is the **top-level module** for the neuromorphic architecture.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       system_top                            │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Node(0,0)│  │ Node(1,0)│  │ Node(0,1)│  │ Node(1,1)│   │
│  │          │  │          │  │          │  │          │   │
│  │ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │   │
│  │ │Router│←┼──┼→│Router│←┼──┼→│Router│←┼──┼→│Router│ │   │
│  │ └──↕───┘ │  │ └──↕───┘ │  │ └──↕───┘ │  │ └──↕───┘ │   │
│  │    ↓     │  │    ↓     │  │    ↓     │  │    ↓     │   │
│  │ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │   │
│  │ │Net IF│ │  │ │Net IF│ │  │ │Net IF│ │  │ │Net IF│ │   │
│  │ └──↕───┘ │  │ └──↕───┘ │  │ └──↕───┘ │  │ └──↕───┘ │   │
│  │    ↓     │  │    ↓     │  │    ↓     │  │    ↓     │   │
│  │ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │   │
│  │ │Neuron│ │  │ │Neuron│ │  │ │Neuron│ │  │ │Neuron│ │   │
│  │ │ Bank │ │  │ │ Bank │ │  │ │ Bank │ │  │ │ Bank │ │   │
│  │ └──────┘ │  │ └──────┘ │  │ └──────┘ │  │ └──────┘ │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│                                                             │
│              External Control Interface ↕                   │
└─────────────────────────────────────────────────────────────┘
```

## Module Hierarchy

### 1. **Routers** (5×5 Crossbar with XY Routing)

- **Ports**: North, South, East, West, Local
- **Virtual Channels**: 4 per port
- **Flow Control**: Ready/Valid handshaking
- **Routing**: XY routing algorithm
- **Address**: 8-bit (upper 4 bits = X coordinate, lower 4 bits = Y coordinate)

### 2. **Network Interfaces**

- **Clock Domain Crossing**: Handles CPU clock ↔ Network clock
- **Protocol Conversion**: AXI4-Lite ↔ NoC packets
- **FIFOs**: 4-deep for buffering
- **Interrupts**: Generates CPU interrupts on spike reception

### 3. **Neuron Banks**

- **Neurons**: 4 LIF/Izhikevich neurons per bank
- **Configuration**: CPU-addressable registers
- **Computation**: IEEE 754 floating-point arithmetic
- **RNG**: Pseudo-random number generator for stochastic behavior

## Parameters

| Parameter              | Default | Description                     |
| ---------------------- | ------- | ------------------------------- |
| `MESH_SIZE_X`          | 2       | Number of nodes in X dimension  |
| `MESH_SIZE_Y`          | 2       | Number of nodes in Y dimension  |
| `ROUTER_ADDR_WIDTH`    | 8       | Router address width (bits)     |
| `NUM_NEURONS_PER_BANK` | 4       | Neurons per bank                |
| `INSTR_MEM_SIZE`       | 256     | Instruction memory size (words) |
| `DATA_MEM_SIZE`        | 256     | Data memory size (words)        |

## Ports

### Clock and Reset

- **`cpu_clk`**: CPU/neuron bank clock domain (typically 50 MHz)
- **`net_clk`**: Network clock domain (typically 100 MHz)
- **`rst_n`**: Active-low asynchronous reset

### External Control Interface

- **`ext_node_select[7:0]`**: Select node for external access (format: `{X[3:0], Y[3:0]}`)
- **`ext_addr[7:0]`**: Register address within selected node
- **`ext_write_en`**: Write enable signal
- **`ext_read_en`**: Read enable signal
- **`ext_write_data[31:0]`**: Data to write
- **`ext_read_data[31:0]`**: Data read from selected node
- **`ext_ready`**: Transaction complete signal

### Debug Outputs

- **`node_interrupts[TOTAL_NODES-1:0]`**: Interrupt status for each node
- **`node_spike_detected[TOTAL_NODES-1:0]`**: Spike detection for each node
- **`debug_router_00_north_out_packet[31:0]`**: Router(0,0) north output packet
- **`debug_router_00_north_out_valid`**: Router(0,0) north output valid

## Address Map

### Neuron Bank Registers (per node)

Each node has a neuron bank with the following address map:

#### Neuron Configuration (8 registers per neuron)

```
Base Address = Neuron_ID × 8

Offset  | Register      | Description
--------|---------------|------------------------------------------
+0x00   | Type          | 0=LIF, 1=Izhikevich
+0x01   | v_th          | Threshold voltage (IEEE 754 float)
+0x02   | a             | Parameter 'a' (IEEE 754 float)
+0x03   | b             | Parameter 'b' (IEEE 754 float)
+0x04   | c             | Reset voltage (IEEE 754 float)
+0x05   | d             | Parameter 'd' (IEEE 754 float)
+0x06   | Control       | [0]=enable, [1]=start, others reserved
+0x07   | Status        | [0]=spike, [1]=busy, others reserved
```

#### Input Current Registers

```
Base Address = 0x80

Offset  | Register      | Description
--------|---------------|------------------------------------------
+0x00   | Input_0       | Input current for neuron 0 (IEEE 754)
+0x04   | Input_1       | Input current for neuron 1 (IEEE 754)
+0x08   | Input_2       | Input current for neuron 2 (IEEE 754)
+0x0C   | Input_3       | Input current for neuron 3 (IEEE 754)
```

#### RNG and Status Registers

```
Address | Register          | Description
--------|-------------------|----------------------------------------
0xC0    | RNG_SEED          | Random number generator seed
0xC1    | RNG_OUTPUT        | Random number output (read-only)
0xC2    | SPIKE_STATUS      | Spike status bitmap (bit per neuron)
```

## Usage Example

### 1. Configuring a LIF Neuron

```verilog
// Select Node (0,0)
ext_node_select = 8'h00;

// Configure Neuron 0 as LIF
ext_addr = 8'h00;  // Type register
ext_write_data = 32'h0000_0000;  // LIF type
ext_write_en = 1;
@(posedge cpu_clk);
ext_write_en = 0;

// Set threshold voltage: -50.0 (0xC2480000)
ext_addr = 8'h01;
ext_write_data = 32'hC2480000;
ext_write_en = 1;
@(posedge cpu_clk);
ext_write_en = 0;

// Set leak parameter 'a': 0.95 (0x3F733333)
ext_addr = 8'h02;
ext_write_data = 32'h3F733333;
ext_write_en = 1;
@(posedge cpu_clk);
ext_write_en = 0;

// Set input weight 'b': 0.1 (0x3DCCCCCD)
ext_addr = 8'h03;
ext_write_data = 32'h3DCCCCCD;
ext_write_en = 1;
@(posedge cpu_clk);
ext_write_en = 0;

// Enable neuron
ext_addr = 8'h06;
ext_write_data = 32'h0000_0001;
ext_write_en = 1;
@(posedge cpu_clk);
ext_write_en = 0;
```

### 2. Injecting Input Current

```verilog
// Inject current: 5.0 (0x40A00000) to Neuron 0
ext_addr = 8'h80;  // Input base + (neuron_id × 4)
ext_write_data = 32'h40A00000;
ext_write_en = 1;
@(posedge cpu_clk);
ext_write_en = 0;

// Start computation
ext_addr = 8'h06;  // Control register
ext_write_data = 32'h0000_0003;  // enable + start
ext_write_en = 1;
@(posedge cpu_clk);
ext_write_en = 0;
```

### 3. Reading Neuron Status

```verilog
// Read status register
ext_addr = 8'h07;  // Status register
ext_read_en = 1;
@(posedge cpu_clk);
wait(ext_ready);
status = ext_read_data;
ext_read_en = 0;

// Check busy and spike bits
busy = status[1];
spike = status[0];
```

## Network Communication

### Spike Packet Format (32-bit)

```
 31    24 23    16 15     8 7      0
┌─────────┬─────────┬─────────┬─────────┐
│Src Addr │Dst Addr │ Neuron  │  Data   │
│ (8-bit) │ (8-bit) │  ID     │         │
└─────────┴─────────┴─────────┴─────────┘
```

- **Src Addr**: Source router address (`{X[3:0], Y[3:0]}`)
- **Dst Addr**: Destination router address
- **Neuron ID**: Target neuron identifier
- **Data**: Spike weight or additional information

### Routing

The system uses **XY routing**:

1. Packets first route in the X direction (East/West)
2. Then route in the Y direction (North/South)
3. Finally delivered to the local port

Example route from (0,0) to (1,1):

```
(0,0) → East → (1,0) → North → (1,1)
```

## Testing

### Running the System Testbench

```bash
# Using Makefile (recommended)
make -f Makefile_noc_tests system

# View waveforms
make -f Makefile_noc_tests system_wave

# Or manually with iverilog
iverilog -g2012 -I. -o build/system_top_tb.out testbench/system_top_tb.v
cd build
vvp system_top_tb.out
```

### Test Coverage

The comprehensive testbench (`system_top_tb.v`) includes:

1. **System Initialization** - Verify all nodes are accessible
2. **Neuron Configuration** - Configure LIF neurons across all nodes
3. **Single Neuron Computation** - Test individual neuron operation
4. **Spike Detection** - Verify spike generation and interrupt signals
5. **Multi-Node Operation** - Test simultaneous neuron computations
6. **Network Communication** - Monitor NoC packet flow

## Performance Characteristics

### Timing

- **Router Latency**: 1-2 cycles per hop
- **Network Interface Latency**: 2-4 cycles (CDC + packetization)
- **Neuron Computation**: 6 cycles (LIF), 10 cycles (Izhikevich)
- **Total Spike Latency**: ~10-20 cycles (source → destination)

### Throughput

- **Router**: Up to 1 packet per cycle per port
- **Network Interface**: Limited by AXI4-Lite handshaking
- **Neuron Bank**: 1 neuron update per 6-10 cycles

### Clock Frequencies

- **CPU Clock**: 20-50 MHz (typical)
- **Network Clock**: 50-100 MHz (can be higher)
- **Clock Ratio**: Network can be 2× CPU for better throughput

## Integration with RISC-V CPU

The system is designed to integrate with a RISC-V CPU core via custom instructions:

### Custom Instructions (Planned)

```assembly
# Configure neuron
neuron.config rd, rs1, rs2    # Configure neuron parameters

# Inject spike
neuron.inject rd, rs1         # Inject input current

# Read status
neuron.status rd, rs1         # Read neuron status

# Network send
noc.send rs1, rs2             # Send packet to destination

# Network receive
noc.recv rd                   # Receive packet (blocking)
```

## Known Limitations

1. **FPU Issues**: Current IEEE 754 FPU modules have calculation bugs

   - Multiplication: `0.1 × 5.0 = 0.0` (incorrect)
   - Addition: `-61.75 + 0.0 = -34.25` (incorrect)
   - **Solution**: Replace with Berkeley HardFloat or OpenCores FPU

2. **Memory Interface**: Simplified for demonstration

   - No proper memory controller
   - No caching or buffering
   - Single-cycle memory access assumed

3. **CPU Integration**: CPU cores not fully integrated
   - External interface used for testing
   - Custom instructions not implemented
   - No instruction memory management

## Future Enhancements

1. **FPU Replacement** - Integrate reliable IEEE 754 FPU
2. **Full CPU Integration** - Complete RISC-V CPU with custom instructions
3. **Advanced Routing** - Adaptive routing, multicast support
4. **Larger Meshes** - Scale to 4×4, 8×8 configurations
5. **Power Management** - Clock gating, voltage scaling
6. **Hardware Accelerators** - Dedicated spike routing, STDP learning

## File Structure

```
system_top.v                    # Top-level system module
testbench/system_top_tb.v       # Comprehensive testbench

Dependencies:
  noc/router.v                  # NoC router
  noc/network_interface.v       # Network interface
  neuron_bank/neuron_bank.v     # Neuron bank
  neuron_bank/neuron_core.v     # Individual neuron
  fpu/*.v                       # IEEE 754 FPU modules
```

## References

- Research Paper: "Neuromorphic NoC Architecture for SNNs"
- RISC-V ISA Specification
- IEEE 754 Floating-Point Standard
- NoC Design Principles (Dally & Towles)

---

**Last Updated**: November 2, 2025  
**Version**: 1.0  
**Status**: ✅ Module complete, ⚠️ FPU needs replacement
