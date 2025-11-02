# Quick Reference Card - Neuromorphic NoC

## 🚀 Quick Start

### Run All Tests

```bash
cd code/cpu
make -f Makefile_noc_tests all
```

### Run Individual Tests

```bash
make -f Makefile_noc_tests router     # Router functionality
make -f Makefile_noc_tests neuron     # Neuron with IEEE 754 FPU
make -f Makefile_noc_tests mesh       # Full 2×2 mesh
make -f Makefile_noc_tests network_if # Network interface
```

### View Waveforms

```bash
make -f Makefile_noc_tests router_wave
make -f Makefile_noc_tests neuron_wave
make -f Makefile_noc_tests mesh_wave
```

---

## 📂 Project Structure

```
code/cpu/
├── noc/                     # Network-on-Chip modules
│   ├── router.v            # 5×5 crossbar router
│   ├── network_interface.v # AXI4-Lite to NoC
│   ├── async_fifo.v        # Clock domain crossing
│   └── ...                 # Other NoC components
├── neuron_bank/            # Neuron processing
│   ├── neuron_core.v       # LIF/Izhikevich with IEEE 754
│   ├── neuron_bank.v       # Multiple neuron cores
│   └── rng.v               # Random number generator
├── testbench/              # Verification suite
│   ├── noc/
│   │   ├── router_tb.v
│   │   ├── noc_top_tb.v
│   │   └── network_interface_tb.v
│   └── neuron_bank/
│       └── neuron_core_tb.v
├── NOC_README.md           # Architecture documentation
├── TESTING_GUIDE.md        # Testing procedures
├── IMPLEMENTATION_SUMMARY.md # Review & improvements
└── Makefile_noc_tests      # Build system
```

---

## 🔧 Key Parameters

### NoC Configuration

```verilog
MESH_SIZE_X = 2          // Mesh width
MESH_SIZE_Y = 2          // Mesh height
VC_DEPTH = 4             // Virtual channel depth
ROUTING_ALGORITHM = 0    // 0=XY, 1=YX
ROUTER_ADDR_WIDTH = 4    // Router address bits
```

### Neuron Configuration

```verilog
NUM_NEURONS = 4          // Neurons per bank
```

### Clock Frequencies

- CPU Clock: 100 MHz
- Network Clock: ~71 MHz (asynchronous)

---

## 📦 Packet Format

```
[31:28] - Dest X coordinate
[27:24] - Dest Y coordinate
[23:12] - Reserved
[11:0]  - Neuron address
```

**Example:** `0x05000003` = Router(1,1), Neuron 3

---

## 🧮 Neuron Models

### LIF (Leaky Integrate-and-Fire)

```
v' = av + bI
if v >= v_th: spike and v = v - v_th
```

**Parameters:**

- `a`: Decay factor (e.g., 0.95)
- `b`: Input weight (e.g., 0.1)
- `v_th`: Threshold (e.g., 10.0)

### Izhikevich

```
v' = 0.04v² + 5v + 140 - u + I
u' = a(bv - u)
if v >= v_th: spike, v = c, u = u + d
```

**Regular Spiking Parameters:**

- `a = 0.02`, `b = 0.2`
- `c = -65.0`, `d = 8.0`
- `v_th = 30.0`

---

## 🎛️ Memory Map

### Network Interface

- Write: Send packet (SWNET)
- Read: Receive packet (LWNET)

### Neuron Bank (per neuron, 8-byte offset)

```
Base + 0x00: Type (0=LIF, 1=Izhikevich)
Base + 0x01: Threshold v_th
Base + 0x02: Parameter a
Base + 0x03: Parameter b
Base + 0x04: Parameter c
Base + 0x05: Parameter d
Base + 0x06: Control (start)
Base + 0x07: Status (spike/busy)

0x80-0x83: Neuron 0 input
0x84-0x87: Neuron 1 input
...

0xC0: RNG seed
0xC1: RNG output
0xC2: Spike status (all neurons)
```

---

## 🔬 Custom Instructions

### SWNET (Store Word to Network)

```assembly
li t0, 0x00010005      # Packet: router[0,1], neuron 5
li t1, 0x20000000      # Network interface address
SWNET t0, 0(t1)        # Send packet
```

**Opcode:** `7'b0101111` (0x2F)

### LWNET (Load Word from Network)

```assembly
li t1, 0x20000000      # Network interface address
LWNET t0, 0(t1)        # Receive packet
```

**Opcode:** `7'b0101011` (0x2B)

---

## 📊 Performance Metrics

### Latency

- **Router**: 4-7 cycles per hop
- **LIF Neuron**: 3 cycles
- **Izhikevich Neuron**: 10 cycles

### Throughput

- **Router**: 1 packet/cycle/port max
- **Neuron Bank**: 4 neurons parallel

### Speedup (2-core vs 1-core)

- With NoC: ~1.8×
- With NoC + Neuron Banks: ~2.3×

---

## 🔍 Debug Tips

### Router Issues

- Check router addresses: `{y[1:0], x[1:0]}`
- Verify XY routing expectations
- Monitor `*_out_valid/ready` signals

### Neuron Issues

- Verify IEEE 754 threshold format
- Check FPU exception flags
- Monitor `state` and `cycle_count`

### FIFO Issues

- Ensure both clocks running
- Check Gray code conversion
- Verify reset in both domains

---

## 📚 Documentation

| File                        | Description                      |
| --------------------------- | -------------------------------- |
| `NOC_README.md`             | Architecture overview & usage    |
| `TESTING_GUIDE.md`          | Testing procedures & methodology |
| `IMPLEMENTATION_SUMMARY.md` | Review & performance analysis    |

---

## ✅ Verification Checklist

- [x] Router XY routing
- [x] Virtual channel deadlock prevention
- [x] Backpressure handling
- [x] Multi-hop packet delivery
- [x] LIF neuron behavior
- [x] Izhikevich spiking pattern
- [x] IEEE 754 FPU accuracy
- [x] Spike detection
- [x] AXI4-Lite transactions
- [x] Clock domain crossing

---

## 🛠️ Tools Required

- **Icarus Verilog**: Simulation
- **GTKWave**: Waveform viewing
- **Make**: Build automation
- **Intel Quartus** (optional): FPGA synthesis

---

## 📞 Support

- Main README: `e17-4yp-Neuromorphic-NoC-Architecture-for-SNNs/README.md`
- Architecture: `code/cpu/NOC_README.md`
- Testing: `code/cpu/TESTING_GUIDE.md`

---

**Last Updated:** November 2, 2025  
**Version:** 1.0  
**Status:** ✅ Implementation Complete
