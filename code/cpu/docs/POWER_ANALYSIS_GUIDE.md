# Power Analysis Guide for Neuromorphic NoC System

## 📋 Overview

This guide explains how to perform power analysis on the neuromorphic Network-on-Chip (NoC) system using **`system_top.v`** - the working, tested design.

**Date**: November 7, 2025  
**Design**: 2×2 Mesh NoC with Neuron Banks  
**Status**: ✅ Verified working (6/6 tests passed)

---

## 🎯 Why Use `system_top.v` Instead of `system_top_with_cpu.v`?

| Aspect              | `system_top.v`                     | `system_top_with_cpu.v` |
| ------------------- | ---------------------------------- | ----------------------- |
| **Compilation**     | ✅ Works                           | ⚠️ Has issues           |
| **Testing**         | ✅ 6/6 passed                      | ❌ Not tested           |
| **Complexity**      | Moderate (16 neurons, 4 routers)   | High (+ 4 CPUs)         |
| **Synthesis**       | ✅ Easier                          | ⚠️ More complex         |
| **Power Relevance** | ✅ Core NoC + neurons              | Full system             |
| **Recommendation**  | **Use for initial power analysis** | Use after fixes         |

**Conclusion**: Start with `system_top.v` for accurate NoC and neuron bank power measurements.

---

## 📁 Files Required

### **1. Top Module**

**File**: `code/cpu/system_top.v` (355 lines)  
**What it includes**:

- 4 routers (5-port each, XY routing, 4 virtual channels)
- 4 network interfaces (AXI4-Lite with async FIFOs)
- 4 neuron banks (4 neurons each = 16 total)
- Dual clock domains (cpu_clk: 50 MHz, net_clk: 100 MHz)
- Full 2×2 mesh topology

### **2. Testbench**

**File**: `code/cpu/testbench/system_top_tb.v` (530 lines)  
**What it tests**:

- Test 1: System initialization
- Test 2: Neuron configuration via external interface
- Test 3: Single neuron computation
- Test 4: Spike detection
- Test 5: Multi-node parallel operation
- Test 6: Network communication monitoring

**Result**: ✅ ALL 6 TESTS PASSED (100% pass rate)

### **3. Source File List**

**File**: `code/power/system_top_src.f` (should exist)  
**If missing**, use this list:

```verilog-filelist
# Include directories
+incdir+../cpu/fpu
+incdir+../cpu/noc
+incdir+../cpu/neuron_bank
+incdir+../cpu/instruction_memory

# FPU Components (for neuron computations)
../cpu/fpu/Priority Encoder.v
../cpu/fpu/Addition-Subtraction.v
../cpu/fpu/Multiplication.v
../cpu/fpu/Division.v
../cpu/fpu/Comparison.v
../cpu/fpu/Converter.v
../cpu/fpu/Iteration.v
../cpu/fpu/fpu.v

# NoC Components
../cpu/noc/async_fifo.v
../cpu/noc/input_router.v
../cpu/noc/rr_arbiter.v
../cpu/noc/virtual_channel.v
../cpu/noc/input_module.v
../cpu/noc/output_module.v
../cpu/noc/router.v
../cpu/noc/network_interface.v

# Neuron Bank Components
../cpu/neuron_bank/rng.v
../cpu/neuron_bank/neuron_core.v
../cpu/neuron_bank/neuron_bank.v

# Instruction Memory (simplified)
../cpu/instruction_memory/instruction_memory.v

# System Top
../cpu/system_top.v
```

---

## 🔧 Power Analysis Workflows

### **Option 1: FPGA Power Analysis (Intel Quartus / Xilinx Vivado)**

#### **A. Intel Quartus Prime (Cyclone IV E - as in paper)**

**Step 1: Create Quartus Project**

```tcl
# Create new project
project_new -overwrite neuromorphic_noc

# Set device (as used in paper experiments)
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE115F29C7

# Set top-level entity
set_global_assignment -name TOP_LEVEL_ENTITY system_top

# Add source files
set_global_assignment -name VERILOG_FILE system_top.v
set_global_assignment -name SEARCH_PATH ../cpu/noc
set_global_assignment -name SEARCH_PATH ../cpu/neuron_bank
set_global_assignment -name SEARCH_PATH ../cpu/fpu
set_global_assignment -name SEARCH_PATH ../cpu/instruction_memory

# Clock constraints
create_clock -name cpu_clk -period 20.000 [get_ports cpu_clk]
create_clock -name net_clk -period 10.000 [get_ports net_clk]
```

**Step 2: Synthesize**

```bash
quartus_sh --flow compile neuromorphic_noc
```

**Step 3: Generate Switching Activity File (VCD)**

```bash
# Run simulation with VCD dump enabled (testbench already has this)
vsim -do "run -all" system_top_tb

# This generates: system_top_tb.vcd
```

**Step 4: Run Power Analysis**

```tcl
# In Quartus Power Analyzer
# Tools > Power Play Power Analyzer

# Import VCD file
set_power_file_name system_top_tb.vcd

# Run power analysis
execute_flow -compile_power
```

**Step 5: Get Results**

```tcl
# View reports
report_power -file power_report.txt

# Key metrics:
# - Total power (mW)
# - Dynamic power (mW)
# - Static power (mW)
# - Power by hierarchy (routers, neuron banks, FIFOs)
# - Clock network power
```

---

#### **B. Xilinx Vivado (7-series or UltraScale)**

**Step 1: Create Vivado Project**

```tcl
# Create project
create_project neuromorphic_noc ./vivado_project -part xc7a100tcsg324-1

# Add sources
add_files -fileset sources_1 [glob ../cpu/noc/*.v]
add_files -fileset sources_1 [glob ../cpu/neuron_bank/*.v]
add_files -fileset sources_1 [glob ../cpu/fpu/*.v]
add_files -fileset sources_1 ../cpu/system_top.v

# Add testbench
add_files -fileset sim_1 testbench/system_top_tb.v

# Set top module
set_property top system_top [current_fileset]
```

**Step 2: Add Clock Constraints (XDC)**
Create `clocks.xdc`:

```tcl
create_clock -period 20.000 -name cpu_clk [get_ports cpu_clk]
create_clock -period 10.000 -name net_clk [get_ports net_clk]

# Asynchronous clock groups (cpu_clk and net_clk are independent)
set_clock_groups -asynchronous \
    -group [get_clocks cpu_clk] \
    -group [get_clocks net_clk]
```

**Step 3: Synthesize and Implement**

```tcl
launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -jobs 4
wait_on_run impl_1
```

**Step 4: Generate VCD**

```tcl
# Run simulation
launch_simulation
run 100us
write_vcd system_top_power.vcd
```

**Step 5: Run Power Analysis**

```tcl
# Open implemented design
open_run impl_1

# Set switching activity from VCD
read_saif system_top_power.vcd

# Run power analysis
report_power -file power_report.txt -advisory
```

**Results Include**:

- On-chip power summary
- Power by hierarchy (each router, neuron bank)
- Clock network power
- Signal power
- Logic power
- DSP power (for FPU multipliers)
- BRAM power

---

### **Option 2: ASIC Power Analysis (Synopsys PrimeTime PX)**

**For academic/research use:**

**Step 1: Synthesis with Design Compiler**

```tcl
# Read design
read_verilog system_top.v
read_verilog -r ../cpu/noc
read_verilog -r ../cpu/neuron_bank
read_verilog -r ../cpu/fpu

# Set constraints
create_clock -name cpu_clk -period 20 [get_ports cpu_clk]
create_clock -name net_clk -period 10 [get_ports net_clk]

# Synthesize
compile_ultra

# Write netlist
write -format verilog -hierarchy -output system_top_synth.v
write_sdc system_top.sdc
```

**Step 2: Generate VCD from Simulation**

```bash
# Run post-synthesis simulation with VCD
vcs system_top_synth.v testbench/system_top_tb.v +vcs+dumpvars+system_top.vcd
./simv
```

**Step 3: Power Analysis with PrimeTime PX**

```tcl
# Read netlist
read_verilog system_top_synth.v

# Read constraints
read_sdc system_top.sdc

# Read switching activity
read_vcd system_top.vcd -strip_path system_top_tb/dut

# Update power
update_power

# Report power
report_power > power_report.txt
report_power -hierarchy > power_hierarchy.txt
```

---

### **Option 3: Open-Source Flow (Yosys + OpenSTA)**

**Step 1: Synthesize with Yosys**

```tcl
# synthesis script (synth.ys)
read_verilog system_top.v
read_verilog -Idir ../cpu/noc ../cpu/noc/*.v
read_verilog -Idir ../cpu/neuron_bank ../cpu/neuron_bank/*.v
read_verilog -Idir ../cpu/fpu ../cpu/fpu/*.v

synth -top system_top
dfflibmap -liberty /path/to/liberty/file.lib
abc -liberty /path/to/liberty/file.lib
clean

write_verilog system_top_synth.v
```

```bash
yosys synth.ys
```

**Step 2: Static Timing Analysis (OpenSTA)**

```tcl
# sta.tcl
read_liberty /path/to/liberty/file.lib
read_verilog system_top_synth.v
link_design system_top

create_clock -name cpu_clk -period 20 [get_ports cpu_clk]
create_clock -name net_clk -period 10 [get_ports net_clk]

report_checks
```

**Step 3: Power Estimation (requires VCD)**

```bash
# Simulate to get VCD
iverilog -o sim system_top_synth.v testbench/system_top_tb.v
vvp sim
# Generates system_top_tb.vcd

# Use VCD with power tool (e.g., gl_power)
gl_power -liberty tech.lib -vcd system_top_tb.vcd -top system_top
```

---

## 📊 Expected Power Analysis Results

### **Component Power Breakdown** (Estimated)

| Component              | Count | Power per Unit | Total Power    |
| ---------------------- | ----- | -------------- | -------------- |
| **Routers**            | 4     | ~15-25 mW      | 60-100 mW      |
| **Network Interfaces** | 4     | ~10-15 mW      | 40-60 mW       |
| **Neuron Banks**       | 4     | ~20-30 mW      | 80-120 mW      |
| **- Neuron Cores**     | 16    | ~1-2 mW        | 16-32 mW       |
| **- FPU (per bank)**   | 4     | ~3-5 mW        | 12-20 mW       |
| **Async FIFOs**        | 8     | ~2-3 mW        | 16-24 mW       |
| **Clock Networks**     | 2     | ~5-10 mW       | 10-20 mW       |
| **Interconnect**       | -     | -              | 20-40 mW       |
| **Static (Leakage)**   | -     | -              | 30-50 mW       |
| **TOTAL**              |       |                | **266-434 mW** |

**Note**: Actual values depend on:

- Technology node (45nm, 28nm, etc.)
- Operating frequency
- Activity factor (switching rate)
- Temperature
- Supply voltage

### **Activity-Based Power**

| Scenario            | Description                       | Expected Power         |
| ------------------- | --------------------------------- | ---------------------- |
| **Idle**            | No neuron activity, no packets    | 30-50 mW (static only) |
| **Low Activity**    | 10% neurons active                | 100-150 mW             |
| **Medium Activity** | 50% neurons active                | 250-350 mW             |
| **High Activity**   | 100% neurons active, full traffic | 400-500 mW             |

---

## 🎯 Recommended Workflow for Your Analysis

### **Step-by-Step Process**

**1. Verify Design Compiles**

```bash
cd code/cpu
iverilog -g2012 -f ../power/system_top_src.f testbench/system_top_tb.v -o build/system_top_tb.vvp
```

**2. Run Simulation with VCD Dump**

```bash
vvp build/system_top_tb.vvp
# Generates: system_top_tb.vcd
```

**3. Analyze VCD Statistics**

```bash
# Check VCD file size and signal count
ls -lh system_top_tb.vcd

# Optional: View waveforms
gtkwave system_top_tb.vcd
```

**4. Choose Tool Based on Target**

| If you have...        | Use...                     | For...               |
| --------------------- | -------------------------- | -------------------- |
| Intel FPGA license    | Quartus PowerPlay          | Accurate FPGA power  |
| Xilinx FPGA license   | Vivado Power Analysis      | Accurate FPGA power  |
| University ASIC tools | Synopsys PrimeTime PX      | ASIC power estimates |
| Open-source only      | Yosys + manual calculation | Rough estimates      |

**5. Synthesize Design**

- Follow tool-specific synthesis steps above
- Ensure design meets timing (50 MHz / 100 MHz clocks)

**6. Run Power Analysis**

- Import VCD file
- Run power analysis with tool
- Export reports

**7. Analyze Results**

- Total power consumption
- Power breakdown by module
- Clock network power
- Dynamic vs. static power ratio

**8. Optimize (if needed)**

- Clock gating for idle neurons
- Reduce virtual channel depth
- Lower clock frequency for power-constrained scenarios

---

## 📈 Metrics to Report

### **For Research Paper / Thesis**

1. **Total System Power** (mW)

   - At different activity levels (idle, 25%, 50%, 75%, 100%)

2. **Power Breakdown**

   - NoC power (routers + network interfaces)
   - Computation power (neuron banks + FPU)
   - Memory power (FIFOs, buffers)
   - Clock network power

3. **Energy per Spike** (pJ/spike)

   - Total energy / number of spikes generated

4. **Energy per Packet** (pJ/packet)

   - NoC energy / packets transmitted

5. **Power Efficiency**

   - Synaptic operations per second per watt (SOPS/W)
   - Comparisons with other neuromorphic systems

6. **Scaling Analysis**
   - Power vs. mesh size (2×2, 4×4, 8×8)
   - Power vs. neurons per bank

---

## 🔍 Verification Checklist

Before running power analysis, ensure:

- [x] Design compiles without errors
- [x] All 6 testbench tests pass
- [x] VCD file is generated (should be ~10-100 MB)
- [ ] Clock constraints are set correctly
- [ ] Synthesis completes successfully
- [ ] Timing constraints are met
- [ ] VCD captures realistic workload (not just idle)

---

## 📚 Additional Resources

### **VCD File Tips**

The testbench already includes VCD dump:

```verilog
// In system_top_tb.v
initial begin
    $dumpfile("system_top_tb.vcd");
    $dumpvars(0, system_top_tb);
end
```

**To reduce VCD size** (if too large):

```verilog
// Dump only specific hierarchies
$dumpvars(1, system_top_tb.dut.router_inst_*);
$dumpvars(1, system_top_tb.dut.neuron_bank_*);
```

### **Typical VCD Statistics**

For 100 µs simulation:

- File size: 50-200 MB
- Signals: 500-2000
- Value changes: 50K-500K

---

## 🎉 Summary

**Use `system_top.v` for power analysis because**:

1. ✅ It works (tested, verified)
2. ✅ Represents core neuromorphic functionality
3. ✅ Easier to synthesize
4. ✅ Provides accurate NoC + neuron power data

**Power analysis workflow**:

1. Compile → 2. Simulate (generate VCD) → 3. Synthesize → 4. Analyze power

**Expected result**: 250-450 mW total power for 2×2 mesh with 16 neurons

---

**Questions?** After power analysis, you can compare with `system_top_with_cpu.v` once compilation issues are resolved.
