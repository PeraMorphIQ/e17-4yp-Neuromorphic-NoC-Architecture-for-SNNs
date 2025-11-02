# Assembly Programs README

## Overview

This directory contains example assembly programs for the RISC-V RV32IMF cores in the neuromorphic NoC architecture. These programs demonstrate SNN initialization, configuration, and simulation tasks.

## Programs

### 1. `snn_init.s` - SNN Initialization and Configuration

**Purpose**: Complete initialization program for setting up neurons and handling spike events.

**Features**:

- Configure LIF neurons (parameters: a, b, v_th)
- Configure Izhikevich neurons (parameters: a, b, c, d, v_th)
- Inject input current to neurons
- Check spike status
- Propagate spikes via network (SWNET)
- Handle incoming spikes via ISR (LWNET)

**Memory Map**:

```
Neuron Bank Base: 0x80000000
Per-neuron stride: 0x20 (32 bytes)

Neuron N offsets:
  0x00: Type (0=LIF, 1=Izhikevich)
  0x04: Threshold (v_th) - IEEE 754 float
  0x08: Parameter 'a' - IEEE 754 float
  0x0C: Parameter 'b' - IEEE 754 float
  0x10: Parameter 'c' - IEEE 754 float
  0x14: Parameter 'd' - IEEE 754 float
  0x18: Input buffer - IEEE 754 float
  0x1C: Status (bit 0: spike, bit 1: busy)
```

**Key Functions**:

- `configure_lif_neuron(neuron_id)` - Setup LIF neuron
- `configure_izhikevich_neuron(neuron_id)` - Setup Izhikevich neuron
- `inject_current(neuron_id, current)` - Inject input current
- `check_spike(neuron_id) -> bool` - Check if neuron spiked
- `propagate_spike(src, dest_node, dest_neuron, weight)` - Send spike via NoC
- `spike_isr()` - Interrupt handler for incoming spikes

**Usage**:

```assembly
# Initialize
jal configure_lif_neuron    # Configure neuron 0

# Inject current
li a0, 0                    # Neuron ID
li a1, 0x40A00000          # Current = 5.0
jal inject_current

# Check for spike
li a0, 0
jal check_spike
beqz a0, no_spike

# Propagate spike
li a0, 0                   # Source neuron
li a1, 0x11                # Dest node (1,1)
li a2, 2                   # Dest neuron 2
li a3, 0x40000000         # Weight 2.0
jal propagate_spike
```

---

### 2. `pattern_recognition.s` - Simple Pattern Recognition

**Purpose**: Demonstrates a simple 2-layer SNN for pattern classification.

**Architecture**:

- Input layer: 4 neurons (pattern encoding)
- Output layer: 2 neurons (classification)
- Patterns:
  - Pattern A: [1,0,1,0] → Output 0 spikes
  - Pattern B: [0,1,0,1] → Output 1 spikes

**Workflow**:

1. Configure input neurons (low threshold LIF)
2. Present Pattern A by injecting current to neurons 0 and 2
3. Wait for propagation and check output
4. Present Pattern B by injecting current to neurons 1 and 3
5. Check classification result

**Key Functions**:

- `configure_input_neuron(id, threshold)` - Setup input neuron
- `present_pattern_a()` - Inject pattern A
- `present_pattern_b()` - Inject pattern B
- `check_output_neurons()` - Read classification result

**Example Patterns**:

```
Pattern A [1,0,1,0]:
  Neuron 0: 100.0 current
  Neuron 1: 0.0 current
  Neuron 2: 100.0 current
  Neuron 3: 0.0 current

Pattern B [0,1,0,1]:
  Neuron 0: 0.0 current
  Neuron 1: 100.0 current
  Neuron 2: 0.0 current
  Neuron 3: 100.0 current
```

---

### 3. `multi_node_comm.s` - Multi-Node Communication Test

**Purpose**: Test inter-node spike propagation across the 2×2 mesh NoC.

**Test Scenario**:

```
Node (0,0) → Node (1,0)
     ↓           ↓
Node (0,1) → Node (1,1)
```

**Workflow**:

1. Node (0,0) initializes source neuron
2. Inject current to neuron 0
3. On spike, propagate to:
   - Node (1,0), Neuron 1 (weight: 2.0)
   - Node (0,1), Neuron 2 (weight: 3.0)
4. Intermediate nodes receive spikes via ISR
5. Process and forward to Node (1,1)

**Key Functions**:

- `node_specific_init()` - Per-node initialization
- `multi_node_test()` - Run communication test
- `propagate_spike(src, dest_node, dest_neuron, weight)` - Send spike
- `spike_isr()` - Handle received spikes

**Packet Format**:

```
31           16 15            0
┌──────────────┬──────────────┐
│  Dest Node   │  Neuron ID   │
│  (Y[7:4],X[3:0])  (ID[15:0])  │
└──────────────┴──────────────┘
```

---

## Custom Instructions

### LWNET - Load Word from Network

**Encoding**: (Custom R-type)

```
31    25 24  20 19  15 14  12 11   7 6    0
┌───────┬──────┬──────┬──────┬──────┬──────┐
│funct7 │ rs2  │ rs1  │funct3│  rd  │opcode│
└───────┴──────┴──────┴──────┴──────┴──────┘
```

**Usage**:

```assembly
LWNET rd, rs1, offset
# rd = packet from network FIFO
# rs1 = base address (unused)
# offset = 0
```

**Description**: Reads a packet from the network interface receive FIFO. Used in interrupt service routine to handle incoming spikes.

---

### SWNET - Store Word to Network

**Encoding**: (Custom S-type)

```
31    25 24  20 19  15 14  12 11   7 6    0
┌───────┬──────┬──────┬──────┬──────┬──────┐
│funct7 │ rs2  │ rs1  │funct3│imm   │opcode│
└───────┴──────┴──────┴──────┴──────┴──────┘
```

**Usage**:

```assembly
SWNET rs1, rs2, offset
# rs1 = weight data (IEEE 754 float)
# rs2 = packet (dest_node[31:16] | neuron_id[15:0])
# offset = 0
```

**Description**: Sends a spike packet to the network interface transmit FIFO for propagation to destination neuron.

---

## IEEE 754 Float Constants

Common values used in programs:

```assembly
# Positive values
0x00000000  # 0.0
0x3F800000  # 1.0
0x40000000  # 2.0
0x40400000  # 3.0
0x40A00000  # 5.0
0x41000000  # 8.0
0x41F00000  # 30.0
0x42480000  # 50.0
0x42C80000  # 100.0

# Negative values
0xBF800000  # -1.0
0xC2480000  # -50.0
0xC2820000  # -65.0

# Small values
0x3CA3D70A  # 0.02
0x3D23D70A  # 0.04
0x3E4CCCCD  # 0.2
0x3F000000  # 0.5
```

---

## Compilation

### Using RISC-V GNU Toolchain

```bash
# Assemble
riscv32-unknown-elf-as -march=rv32imf -mabi=ilp32f -o snn_init.o snn_init.s

# Link
riscv32-unknown-elf-ld -T linker.ld -o snn_init.elf snn_init.o

# Convert to binary
riscv32-unknown-elf-objcopy -O binary snn_init.elf snn_init.bin

# Generate hex file for memory initialization
riscv32-unknown-elf-objcopy -O verilog snn_init.elf snn_init.hex
```

### Linker Script (`linker.ld`)

```ld
MEMORY
{
    IMEM : ORIGIN = 0x00000000, LENGTH = 4K
    DMEM : ORIGIN = 0x80000000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        *(.text)
        *(.text.*)
    } > IMEM

    .data : {
        *(.data)
        *(.data.*)
    } > DMEM

    .bss : {
        *(.bss)
        *(.bss.*)
    } > DMEM
}
```

---

## Loading Programs into Testbench

In the testbench, use the `load_instruction` task:

```verilog
// Load program to Node (0,0)
load_instruction(2'b00, 32'h00000000, 32'h00000013); // Instruction 0
load_instruction(2'b00, 32'h00000004, 32'h00100093); // Instruction 1
// ... continue for all instructions
```

Or read from hex file:

```verilog
initial begin
    $readmemh("snn_init.hex", imem_data);
    for (i = 0; i < program_size; i = i + 1) begin
        load_instruction(node_id, i*4, imem_data[i]);
    end
end
```

---

## Debugging

### Print Registers in Simulation

Add to testbench:

```verilog
always @(posedge cpu_clk) begin
    if (dut.gen_y[0].gen_x[0].cpu_inst.reg_file_inst.write_enable) begin
        $display("[TIME %0t] Node(0,0) Write: x%0d = %h",
                 $time,
                 dut.gen_y[0].gen_x[0].cpu_inst.reg_file_inst.write_address,
                 dut.gen_y[0].gen_x[0].cpu_inst.reg_file_inst.write_data);
    end
end
```

### Monitor Network Packets

```verilog
always @(posedge net_clk) begin
    if (dut.gen_y[0].gen_x[0].local_to_router_valid) begin
        $display("[TIME %0t] Node(0,0) TX: Packet=%h",
                 $time,
                 dut.gen_y[0].gen_x[0].local_to_router_packet);
    end
end
```

---

## Future Enhancements

1. **Compiler Support**

   - C library for neuron configuration
   - Inline assembly for LWNET/SWNET
   - Automatic weight matrix generation

2. **Advanced Programs**

   - STDP learning algorithm
   - Convolutional SNN layers
   - Recurrent SNN networks

3. **Profiling**
   - Cycle count per operation
   - Network bandwidth utilization
   - Power profiling markers

---

## References

- RISC-V ISA Specification: https://riscv.org/technical/specifications/
- IEEE 754 Floating Point: https://en.wikipedia.org/wiki/IEEE_754
- Research Paper: `../../Research_Paper/conference_101719.tex`

---

**Note**: These programs use pseudo-instructions for LWNET/SWNET. Actual encoding depends on the custom instruction extension implementation in the CPU.
