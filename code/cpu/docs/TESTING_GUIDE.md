# Testing and Verification Guide

## Overview

This document provides comprehensive testing procedures for the Neuromorphic NoC architecture, including router functionality, neuron computation with IEEE 754 FPU, and full mesh integration.

## Test Suite Components

### 1. Router Testbench (`testbench/noc/router_tb.v`)

Tests the 5x5 crossbar router functionality with the following scenarios:

**Test Cases:**

- **Single-hop routing**: Packets traveling one hop (North→South, West→East, etc.)
- **Local delivery**: Packets destined for the current router
- **Multiple simultaneous packets**: Concurrent packet injection from different ports
- **Backpressure handling**: Flow control when output buffers are full

**Expected Results:**

- Correct XY routing decisions
- No packet loss under backpressure
- Fair arbitration between competing packets
- Proper virtual channel utilization

**Run Test:**

```bash
cd code/cpu
make -f Makefile_noc_tests router
```

**View Waveforms:**

```bash
make -f Makefile_noc_tests router_wave
```

---

### 2. Neuron Core Testbench (`testbench/neuron_bank/neuron_core_tb.v`)

Tests both LIF and Izhikevich neuron models with IEEE 754 floating-point arithmetic:

**Test Cases:**

#### LIF (Leaky Integrate-and-Fire) Neuron

- Membrane potential accumulation: `v' = av + bI`
- Spike detection when `v ≥ v_th`
- After-spike reset: `v = v - v_th`

**Parameters:**

- `a = 0.95` (decay factor)
- `b = 0.1` (input weight)
- `v_th = 10.0` (threshold)
- `I = 5.0` (constant input current)

#### Izhikevich Neuron

- Membrane potential: `v' = 0.04v² + 5v + 140 - u + I`
- Recovery variable: `u' = a(bv - u)`
- After-spike reset: `v = c`, `u = u + d`

**Parameters (Regular Spiking):**

- `a = 0.02`
- `b = 0.2`
- `c = -65.0` (reset voltage)
- `d = 8.0` (reset recovery)
- `v_th = 30.0` (threshold)
- `I = 10.0` (constant input current)

**IEEE 754 FPU Integration:**
The neuron core now uses proper IEEE 754 floating-point units:

- `Addition_Subtraction` module for addition/subtraction
- `Multiplication` module for multiplication
- Exception handling for overflow/underflow
- Combinational FPU design (no pipeline latency)

**Run Test:**

```bash
make -f Makefile_noc_tests neuron
```

**Expected Output:**

```
[CONFIG] Configuring LIF Neuron
  Neuron type set to LIF
  Threshold v_th = 10.000000
  Parameter a = 0.950000
  Parameter b = 0.100000

[TEST] LIF Neuron Behavior
  Step 1: v = -61.250000
  Step 2: v = -57.687500
  ...
  Step N: v = 10.543210
    SPIKE DETECTED!
    After reset: v = 0.543210
```

---

### 3. Full Mesh Testbench (`testbench/noc/noc_top_tb.v`)

Tests the complete 2×2 mesh topology with multi-hop routing:

**Test Cases:**

#### Single-hop Routing

- R(0,0) → R(0,1): East direction
- R(0,0) → R(1,0): South direction

#### Multi-hop Routing

- R(0,0) → R(1,1): South then East (XY routing)
- R(0,1) → R(1,0): Cross-diagonal path

#### Stress Tests

- **Multiple simultaneous packets**: All 4 routers inject packets concurrently
- **Convergence test**: All routers send to R(1,1) simultaneously
- **Deadlock prevention**: Virtual channels ensure deadlock-free routing

**Packet Format:**

```
[31:28] - Dest X coordinate
[27:24] - Dest Y coordinate
[23:12] - Reserved
[11:0]  - Neuron address
```

**Run Test:**

```bash
make -f Makefile_noc_tests mesh
```

**Expected Output:**

```
[TEST 3] Diagonal: R(0,0) to R(1,1) [Multi-hop]
  Injecting packet 0x05000003 from R(0,0) to R(1,1)
  Packet injected successfully
  [HOP] R(0,0)->South: 0x05000003
  [HOP] R(1,0)->East: 0x05000003
  [46ns] Packet arrived at R(1,1) local: 0x05000003
```

---

### 4. Network Interface Testbench (`testbench/noc/network_interface_tb.v`)

Tests AXI4-Lite interface and clock domain crossing:

**Test Cases:**

- AXI write transactions (SWNET instruction simulation)
- AXI read transactions (LWNET instruction simulation)
- Async FIFO operation with different clock domains
- Interrupt generation on packet arrival

**Run Test:**

```bash
make -f Makefile_noc_tests network_if
```

---

## Running All Tests

Execute the complete test suite:

```bash
make -f Makefile_noc_tests all
```

This runs all four testbenches sequentially and reports results.

---

## Makefile Targets

| Target              | Description               |
| ------------------- | ------------------------- |
| `make router`       | Test router module        |
| `make neuron`       | Test neuron core with FPU |
| `make mesh`         | Test full 2x2 mesh        |
| `make network_if`   | Test network interface    |
| `make all`          | Run all tests             |
| `make syntax_check` | Check Verilog syntax      |
| `make clean`        | Remove build files        |
| `make help`         | Show available commands   |

**Waveform Viewing:**

- `make router_wave` - View router waveforms in GTKWave
- `make neuron_wave` - View neuron waveforms
- `make mesh_wave` - View mesh waveforms

---

## IEEE 754 FPU Verification

The neuron core now uses proper IEEE 754 floating-point arithmetic instead of placeholder operations.

### FPU Modules Used

1. **Addition_Subtraction.v**

   - Input: Two 32-bit IEEE 754 operands
   - Output: 32-bit IEEE 754 result
   - Handles normalization, rounding, exception cases
   - Combinational (0 cycle latency)

2. **Multiplication.v**
   - Input: Two 32-bit IEEE 754 operands
   - Output: 32-bit IEEE 754 result
   - Handles overflow, underflow, exceptions
   - Combinational (0 cycle latency)

### Verification Methodology

**Test Vectors:**
Create test cases with known floating-point results:

```verilog
// Example: LIF equation v' = av + bI
// With a=0.95, v=-65.0, b=0.1, I=5.0
// Expected: v' = (0.95 × -65.0) + (0.1 × 5.0) = -61.25

config_data = 32'h3F733333;  // a = 0.95
// ... run simulation
// Verify v_out matches -61.25 (0xC2750000)
```

**Comparison with Software Model:**

1. Run neuron equations in Python/C with IEEE 754 arithmetic
2. Compare hardware results against software golden reference
3. Verify bit-exact matches (or acceptable error margins)

**Python Verification Script:**

```python
import struct
import numpy as np

def ieee754_to_float(hex_val):
    return struct.unpack('!f', bytes.fromhex(hex_val))[0]

def float_to_ieee754(f):
    return struct.pack('!f', f).hex()

# LIF test
a = 0.95
v = -65.0
b = 0.1
I = 5.0

v_new = a * v + b * I
print(f"Expected v' = {v_new}")
print(f"IEEE 754: 0x{float_to_ieee754(v_new)}")
```

---

## Performance Metrics

### Latency Measurements

**Router Latency:**

- Single-hop: ~5-10 network clock cycles
- Multi-hop: N × (5-10) cycles, where N = hop count

**Neuron Update Latency:**

- LIF: 3 cycles (2 multiplications + 1 addition)
- Izhikevich: 7 cycles (v update) + 3 cycles (u update) = 10 cycles

**Clock Domain Crossing:**

- FIFO synchronization: 2-3 cycles worst case
- Impact on end-to-end latency: minimal due to async design

### Throughput

**Router Throughput:**

- Maximum: 1 packet per cycle per port (5 packets/cycle total)
- Actual: Limited by virtual channel depth and flow control

**Neuron Bank Throughput:**

- 4 neurons can be updated in parallel
- Each neuron processes independently
- Limited by memory access for configuration/results

---

## Debug Tips

### Common Issues

1. **Router packets not arriving:**

   - Check router addresses are correct (format: `{y[1:0], x[1:0]}`)
   - Verify XY routing algorithm expectations
   - Ensure output ready signals are high

2. **Neuron spikes not detected:**

   - Verify threshold configuration (IEEE 754 format)
   - Check if input current is sufficient
   - Monitor FPU exception flags

3. **Async FIFO issues:**
   - Ensure both clock domains are running
   - Check reset is properly released in both domains
   - Verify Gray code conversion logic

### Waveform Analysis

**Key Signals to Monitor:**

**Router:**

- `state` (in each VC): Shows packet buffering
- `grant_*`: Arbiter decisions
- `*_out_valid/ready`: Flow control handshakes

**Neuron:**

- `state`: FSM progression
- `v`, `u`: Membrane potential and recovery
- `cycle_count`: Multi-cycle operation tracking
- `fp_add_result`, `fp_mul_result`: FPU outputs

**Network Interface:**

- `axi_*`: AXI transaction progress
- `tx_fifo_*/rx_fifo_*`: FIFO status
- `interrupt`: Packet arrival notification

---

## Integration Testing

### Step 1: Module-level Tests

Run individual testbenches to verify each component:

```bash
make router
make neuron
```

### Step 2: Subsystem Tests

Test interconnected modules:

```bash
make mesh
make network_if
```

### Step 3: System-level Tests

Test complete system with CPU integration (future work):

- Load neuron configuration via memory-mapped registers
- Inject spike packets via SWNET instruction
- Read spike results via LWNET instruction
- Verify interrupt-driven spike handling

---

## Future Enhancements

### Additional Tests Needed

1. **Stress Testing**

   - High injection rate scenarios
   - Buffer overflow conditions
   - Long-running stability tests

2. **Coverage Analysis**

   - Code coverage metrics
   - Functional coverage of routing scenarios
   - Corner case verification

3. **FPGA Hardware Testing**

   - Synthesize for Cyclone IV
   - Test on DE2-115 board
   - Measure actual timing and power

4. **Software Integration**
   - CPU driver for neuron bank access
   - SNN application examples
   - Performance profiling tools

---

## References

- IEEE 754-2008 Standard for Floating-Point Arithmetic
- "Izhikevich, E. M. (2003). Simple model of spiking neurons."
- RISC-V ISA Specification
- AXI4-Lite Protocol Specification

---

## Contact

For questions or issues with the test suite, refer to:

- Project README: `e17-4yp-Neuromorphic-NoC-Architecture-for-SNNs/README.md`
- NoC Documentation: `code/cpu/NOC_README.md`
