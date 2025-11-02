# Complete Integration Guide - System Top with RISC-V CPUs

## Overview

This guide covers the complete workflow for building, testing, and analyzing the final neuromorphic NoC architecture with integrated RISC-V processors.

## Table of Contents

1. [Quick Start](#quick-start)
2. [File Structure](#file-structure)
3. [Building and Testing](#building-and-testing)
4. [Power Analysis](#power-analysis)
5. [Programming Guide](#programming-guide)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Prerequisites

- **Icarus Verilog 12.0** or later
- **GTKWave** for waveform viewing
- **Synopsys Design Compiler** (for power analysis)
- **RISC-V GNU Toolchain** (optional, for assembly)

### 5-Minute Test

```powershell
# Navigate to CPU directory
cd d:\Academics\Projects\fyp\repos\e17\e17-4yp-Neuromorphic-NoC-Architecture-for-SNNs\code\cpu

# Compile testbench
iverilog -g2012 -I. -o build/system_top_with_cpu_tb.out testbench/system_top_with_cpu_tb.v

# Run simulation
vvp build/system_top_with_cpu_tb.out

# View waveforms
gtkwave system_top_with_cpu_tb.vcd
```

---

## File Structure

```
code/
├── cpu/
│   ├── system_top_with_cpu.v           # Complete design with CPUs
│   ├── SYSTEM_WITH_CPU_README.md       # Architecture documentation
│   │
│   ├── testbench/
│   │   └── system_top_with_cpu_tb.v    # Comprehensive testbench
│   │
│   ├── programs/
│   │   ├── snn_init.s                  # Initialization program
│   │   ├── pattern_recognition.s       # Pattern recognition example
│   │   ├── multi_node_comm.s           # Multi-node test
│   │   └── README.md                   # Programming guide
│   │
│   ├── cpu/                            # RISC-V RV32IMF core
│   │   ├── cpu.v
│   │   └── control_unit.v
│   │
│   ├── noc/                            # Network-on-Chip
│   │   ├── router/
│   │   └── network_interface/
│   │
│   ├── neuron_bank/                    # Neuron cores
│   │   ├── neuron_bank.v
│   │   └── neuron_core.v
│   │
│   └── instruction_memory/
│       └── instruction_memory.v
│
└── power/
    ├── system_top_with_cpu_src.f      # Complete source list
    ├── config.tcl                      # Updated configuration
    ├── rtla.tcl                        # Synthesis script
    ├── restore_new.tcl                 # Power analysis
    └── sdc/
        └── clocks.sdc                  # Clock constraints
```

---

## Building and Testing

### Step 1: Compile Design

```powershell
# Set up paths
$PROJECT_ROOT = "d:\Academics\Projects\fyp\repos\e17\e17-4yp-Neuromorphic-NoC-Architecture-for-SNNs\code"
cd $PROJECT_ROOT\cpu

# Create build directory
mkdir -Force build

# Compile with Icarus Verilog
iverilog -g2012 `
    -I. `
    -I cpu `
    -I noc/router `
    -I noc/network_interface `
    -I neuron_bank `
    -I fpu `
    -I instruction_memory `
    -o build/system_top_with_cpu_tb.out `
    testbench/system_top_with_cpu_tb.v
```

### Step 2: Run Simulation

```powershell
# Run testbench
vvp build/system_top_with_cpu_tb.out | Tee-Object -FilePath build/test_results.log

# Check results
Select-String -Path build/test_results.log -Pattern "TEST SUMMARY" -Context 0,10
```

### Step 3: Analyze Waveforms

```powershell
# Open in GTKWave
gtkwave system_top_with_cpu_tb.vcd

# Or specify save file
gtkwave system_top_with_cpu_tb.vcd config/system_cpu.gtkw
```

**Key Signals to Monitor**:

- `dut.cpu_clk`, `dut.net_clk` - Clock domains
- `dut.rst_n` - Reset
- `dut.cpu_interrupt[*]` - CPU interrupts
- `dut.spike_out[*]` - Neuron spikes
- `dut.gen_y[0].gen_x[0].cpu_inst.*` - CPU internal state
- `dut.gen_y[0].gen_x[0].router_inst.*` - Router activity
- `dut.gen_y[0].gen_x[0].ni_inst.*` - Network interface

---

## Power Analysis

### Step 1: Generate Waveform Data

```powershell
cd $PROJECT_ROOT\cpu

# Run testbench to generate VCD
vvp build/system_top_with_cpu_tb.out

# Convert VCD to FSDB (requires Verdi/Debussy)
vcd2fsdb system_top_with_cpu_tb.vcd -o build/system_top_with_cpu.fsdb
```

### Step 2: Run Synthesis

```powershell
cd $PROJECT_ROOT\power

# Run RTL analysis (takes 2-4 hours)
design_shell -f rtla.tcl | Tee-Object -FilePath rtla.log
```

**Expected Outputs** (in `results/`):

- `publication_summary.txt` - Key metrics
- `timing_metrics.csv` - Timing data
- `report_power.txt` - Power breakdown
- `report_area.txt` - Area utilization
- `report_qor.txt` - Quality of Results
- `report_timing_critical_path.txt` - Critical path analysis

### Step 3: Run Power Analysis

```powershell
# After synthesis completes
design_shell -f restore_new.tcl | Tee-Object -FilePath restore.log
```

**Expected Outputs**:

- `power_summary.txt` - Total power
- `power_by_module_*.txt` - Hierarchical power
- `rtl_metrics_*.txt` - Design metrics
- `switching_activity.txt` - Signal activity

### Step 4: Extract Results

```powershell
# View key metrics
Get-Content results/publication_summary.txt

# Extract to table
$metrics = Import-Csv results/timing_metrics.csv
$metrics | Format-Table

# Check power breakdown
Get-Content results/power_by_module_2.txt | Select-String -Pattern "gen_y|gen_x"
```

**Expected Metrics** (for 2×2 mesh @ 45nm):

- **Maximum Frequency**: 200-400 MHz
- **Total Power**: 50-100 mW per node
- **Area**: 0.5-1.0 mm² per node
- **Critical Path**: Through FPU (7-10 ns)

---

## Programming Guide

### Assembly Programming

See `programs/README.md` for detailed guide.

**Quick Example**:

```assembly
.section .text
.globl _start

_start:
    # Initialize stack
    li sp, 0x10000

    # Configure neuron 0 as LIF
    li t0, 0x80000000       # Neuron bank base
    li t1, 0                # Type = LIF
    sw t1, 0x00(t0)

    li t1, 0xC2480000       # v_th = -50.0
    sw t1, 0x04(t0)

    # Inject current
    li t1, 0x42C80000       # 100.0
    sw t1, 0x18(t0)

    # Wait for spike
wait_loop:
    lw t1, 0x1C(t0)
    andi t2, t1, 0x01
    beqz t2, wait_loop

    # Spike detected!
    j halt

halt:
    j halt
```

### Compile and Load

```bash
# Compile
riscv32-unknown-elf-as -march=rv32imf -o program.o program.s
riscv32-unknown-elf-ld -T linker.ld -o program.elf program.o
riscv32-unknown-elf-objcopy -O verilog program.elf program.hex

# Load in testbench
$readmemh("program.hex", program_data);
```

---

## Testbench Usage

### Running Specific Tests

Edit `testbench/system_top_with_cpu_tb.v` to enable/disable tests:

```verilog
// Comment out tests you don't want to run
// TEST 1: System Reset
// TEST 2: Program Loading
// TEST 3: Single Neuron Spike
TEST 4: Router Activity         // Enable this
// TEST 5: Multi-node Parallel
// TEST 6: Interrupt Monitoring
// TEST 7: Stability Test
```

### Adding Custom Tests

```verilog
// Add after TEST 7
test_num = test_num + 1;
$display("[TEST %0d] My Custom Test", test_num);

// Your test code here
inject_current(4'h0, 4'h0, 4'h0, 32'h42480000);
#1000;

// Check results
if (spike_out[0]) begin
    $display("✓ TEST %0d PASSED", test_num);
    pass_count = pass_count + 1;
end else begin
    $display("✗ TEST %0d FAILED", test_num);
    fail_count = fail_count + 1;
end
```

### Monitoring Specific Signals

```verilog
// Add to testbench initial block
initial begin
    $monitor("[TIME %0t] Node(0,0) PC=%h Instruction=%h",
             $time,
             dut.gen_y[0].gen_x[0].cpu_inst.INSTRUCTION_ADDRESS,
             dut.gen_y[0].gen_x[0].cpu_inst.INSTRUCTION);
end
```

---

## Troubleshooting

### Compilation Errors

**Error**: `module not found`

```
Solution: Check include paths
iverilog -I. -I cpu -I noc/router -I noc/network_interface ...
```

**Error**: `bit width mismatch`

```
Solution: Check parameter consistency across modules
- PACKET_WIDTH = 32
- DATA_WIDTH = 32
- ADDR_WIDTH = 8
```

### Simulation Issues

**Problem**: CPUs halt immediately

```
Check:
1. Reset timing: rst_n = 0 for at least 100 cycles
2. Instruction memory loaded correctly
3. Check INSTRUCTION signal is not 'x' or 'z'
```

**Problem**: No spikes detected

```
Check:
1. Neuron configuration (threshold, parameters)
2. Input current magnitude (use 50.0 or higher)
3. Wait sufficient cycles (1000+)
4. Check neuron_bank.ready signal
```

**Problem**: Network packets not routing

```
Check:
1. Router valid/ready handshaking
2. XY routing coordinates correct
3. Virtual channel availability
4. Clock domain crossing in network interface
```

### Synthesis Errors

**Error**: `No clocks found`

```
Solution: Check sdc/clocks.sdc
- Port names must match: cpu_clk, net_clk
- Create clocks explicitly if auto-detection fails
```

**Error**: `Timing violations`

```
Expected on first run - script reports achievable frequency
- Check critical path in report_timing_critical_path.txt
- Usually through FPU or router crossbar
- Adjust clock periods if needed
```

### Power Analysis Issues

**Error**: `FSDB file not found`

```
Solution:
1. Check VCD generated: ls system_top_with_cpu_tb.vcd
2. Convert to FSDB: vcd2fsdb system_top_with_cpu_tb.vcd -o build/system_top_with_cpu.fsdb
3. Update path in config.tcl
```

**Error**: `Strip path mismatch`

```
Solution: Update config.tcl
set STRIP_PATH "system_top_with_cpu_tb/dut"
# Must match testbench hierarchy
```

---

## Performance Expectations

### Simulation Time

- **2×2 mesh, 1000 timesteps**: ~5-10 minutes
- **Full test suite (7 tests)**: ~15 minutes
- **With waveform dump**: +50% time

### Synthesis Time

- **RTL Analysis**: 2-4 hours (8 cores)
- **Power Analysis**: 30-60 minutes
- **Total**: ~3-5 hours

### Expected Results

From paper (Section X):

| Design                  | Init (cycles) | Per Timestep (cycles) | Speedup  |
| ----------------------- | ------------- | --------------------- | -------- |
| EXP-1 (1 CPU, no HW)    | 105           | 331                   | 1.0×     |
| EXP-2 (2 CPUs, no HW)   | 105           | 179                   | 1.8×     |
| **EXP-3 (2 CPUs + HW)** | **115**       | **146**               | **2.3×** |

Your 2×2 implementation should show similar trends.

---

## Next Steps

### Short Term

1. ✅ Run testbench - validate basic functionality
2. ✅ Load simple program - test CPU execution
3. ✅ Verify spike propagation - test NoC
4. ⬜ Run synthesis - get power/area metrics
5. ⬜ Optimize critical path - improve frequency

### Medium Term

1. Scale to 4×4 mesh (16 nodes, 64 neurons)
2. Implement STDP learning algorithm
3. Replace FPU with Berkeley HardFloat
4. Add DMA for bulk data transfer
5. Implement multicast routing

### Long Term

1. FPGA implementation (Xilinx/Intel)
2. Create C library for SNN programming
3. Develop compiler for SNN graphs
4. Benchmark against SpiNNaker/DYNAP
5. Tape out 45nm CMOS chip

---

## Resources

### Documentation

- **Architecture**: `SYSTEM_WITH_CPU_README.md`
- **Programming**: `programs/README.md`
- **Power Analysis**: `../power/POWER_ANALYSIS_README.md`
- **Research Paper**: `../../Research_Paper/conference_101719.tex`

### Tools

- **Icarus Verilog**: http://iverilog.icarus.com/
- **GTKWave**: http://gtkwave.sourceforge.net/
- **RISC-V Toolchain**: https://github.com/riscv-collab/riscv-gnu-toolchain
- **Synopsys DC**: (Requires license)

### References

- RISC-V ISA: https://riscv.org/technical/specifications/
- IEEE 754: https://en.wikipedia.org/wiki/IEEE_754
- NoC Design: Dally & Towles, "Principles and Practices of Interconnection Networks"
- SNN Models: Izhikevich, "Simple Model of Spiking Neurons" (2003)

---

## Support

For issues:

1. Check this guide first
2. Review error messages carefully
3. Consult individual README files
4. Check research paper for architecture details

---

**Version**: 1.0  
**Last Updated**: November 3, 2025  
**Status**: Complete and ready for testing
