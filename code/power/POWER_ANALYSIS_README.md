# Power Analysis Guide for System Top Design

## Overview

This directory contains scripts for performing power analysis and synthesis of the `system_top` design (2×2 Mesh NoC with Neuron Banks) using 45nm CMOS technology in Synopsys Design Compiler.

## Design Specifications

### System Top Architecture

- **Top Module**: `system_top`
- **Technology**: 45nm CMOS Process
- **Architecture**: 2×2 Mesh Network-on-Chip
- **Components**:
  - 4 Routers (5×5 crossbar, XY routing)
  - 4 Network Interfaces (Clock Domain Crossing + AXI4-Lite)
  - 4 Neuron Banks (4 neurons each = 16 total neurons)
  - IEEE 754 Floating-Point Units (FPU)

### Clock Domains

- **CPU Clock (`cpu_clk`)**: 50 MHz (20 ns period)
  - External control interface
  - Neuron bank configuration and computation
- **Network Clock (`net_clk`)**: 100 MHz (10 ns period)
  - NoC router mesh
  - Network interfaces
  - Packet routing and switching

## File Structure

```
power/
├── config.tcl              # Shared configuration (design name, paths, parameters)
├── rtla.tcl                # RTL analysis and synthesis script
├── restore_new.tcl         # Power analysis and metrics reporting
├── tz_setup.tcl            # Technology setup (45nm CMOS, constraints, optimization)
├── system_top_src.f        # Source file list for system_top design
├── sdc/
│   └── clocks.sdc          # Clock constraints (dual clock domains)
├── results/                # Output directory for reports
└── RTLA_WORKSPACE/         # Synthesis workspace directory
```

## Prerequisites

### Required Tools

- **Synopsys Design Compiler** (FC2 or later)
- **45nm CMOS Technology Libraries**:
  - NangateOpenCellLibrary (or equivalent)
  - TLU+ parasitic models
  - Technology files (.tf, .map)

### Required Inputs

1. **RTL Source Files**: All listed in `system_top_src.f`
2. **FSDB Waveform**: `../cpu/build/system_top.fsdb`
   - Generated from testbench simulation with VCD-to-FSDB conversion
3. **Technology Files**: Located in `/tech/45nm/` (update paths in `config.tcl`)

## Workflow

### Step 1: Generate FSDB Waveform (if needed)

First, you need to generate the waveform data from your testbench:

```bash
# Navigate to CPU directory
cd ../cpu

# Run testbench to generate VCD
make system  # or: iverilog -g2012 -o build/system_top_tb.out testbench/system_top_tb.v
             #      vvp build/system_top_tb.out

# Convert VCD to FSDB (using Verdi/Debussy)
vcd2fsdb build/system_top_tb.vcd -o build/system_top.fsdb
```

### Step 2: Update Configuration (if needed)

Edit `config.tcl` to adjust paths or parameters:

```tcl
# Key variables to check/modify:
set CORES 8                      # Number of CPU cores for parallel processing
set LIBS_PATH "/tech/45nm/libs"  # Path to your 45nm libraries
set CLTRLS_PATH "/tech/45nm/cltrls"  # Path to TLU+ files
set FSDB_FILE "../cpu/build/system_top.fsdb"  # Path to waveform
```

### Step 3: Run RTL Analysis and Synthesis

```bash
# Navigate to power directory
cd power

# Run RTL analysis (this takes several hours)
design_shell -f rtla.tcl | tee rtla.log
```

This script will:

- Load 45nm CMOS libraries
- Analyze and elaborate the `system_top` design
- Apply clock constraints (dual clock domains)
- Perform RTL optimization
- Export power analysis data
- Characterize maximum operating frequency
- Generate comprehensive reports

**Expected Outputs** (in `results/`):

- `publication_summary.txt` - High-level performance metrics
- `timing_metrics.csv` - Key timing data in CSV format
- `report_power.txt` - Power consumption breakdown
- `report_area.txt` - Area utilization
- `report_qor.txt` - Quality of Results summary
- `report_timing_*.txt` - Detailed timing analysis
- `report_clock.txt` - Clock tree analysis

### Step 4: Run Power Analysis

After RTL analysis completes, run power analysis:

```bash
# Run power analysis
design_shell -f restore_new.tcl | tee restore.log
```

This script will:

- Load synthesized design from workspace
- Read FSDB waveform data
- Compute switching activity
- Generate hierarchical power reports
- Analyze power by component type
- Report RTL metrics

**Expected Outputs** (in `results/`):

- `power_summary.txt` - Overall power consumption
- `power_register.txt` - Register power breakdown
- `power_sequential.txt` - Sequential logic power
- `power_combinational.txt` - Combinational logic power
- `power_by_module_*.txt` - Hierarchical power at different levels
- `rtl_metrics_*.txt` - RTL quality metrics
- `switching_activity.txt` - Signal activity analysis
- `clock_gating.txt` - Clock gating efficiency

## Understanding Results

### Key Metrics to Extract

#### 1. Maximum Operating Frequency

Look in `results/publication_summary.txt`:

```
MAXIMUM FREQUENCY CHARACTERIZATION:
  Critical Path Delay:   X.XX ns
  Maximum Frequency:     XXX.XX MHz
```

#### 2. Power Consumption

Look in `results/power_summary.txt`:

```
Total Power:        X.XXX mW
  Dynamic Power:    X.XXX mW
  Leakage Power:    X.XXX mW
```

#### 3. Area Utilization

Look in `results/report_area.txt`:

```
Total cell area:           XXXXX.XX
Combinational area:        XXXXX.XX
Sequential area:           XXXXX.XX
```

#### 4. Hierarchical Power Breakdown

Look in `results/power_by_module_2.txt` for component-level power:

- Router power consumption
- Network Interface power
- Neuron Bank power
- FPU power

### Publication-Ready Metrics

For research papers, use these key numbers:

1. **Maximum Frequency**: From `publication_summary.txt`

   - Example: "398.27 MHz at 45nm CMOS"

2. **Power Consumption**: From `power_summary.txt`

   - Total power (mW)
   - Power per neuron (total/16)
   - Power efficiency (ops/mW)

3. **Area**: From `report_area.txt`

   - Total area (µm²)
   - Area per neuron
   - Area breakdown by component

4. **Energy per Operation**: Calculate from power and frequency
   - Energy per spike = Power / (Frequency × Spike_Rate)

## Troubleshooting

### Common Issues

1. **"No clocks found after loading constraints"**

   - Check `sdc/clocks.sdc` has correct port names
   - Verify ports exist: `get_ports cpu_clk` and `get_ports net_clk`
   - Solution: Script will attempt to create clocks automatically

2. **"Unable to open FSDB file"**

   - Ensure testbench simulation completed successfully
   - Check VCD file exists: `../cpu/build/system_top_tb.vcd`
   - Convert VCD to FSDB: `vcd2fsdb system_top_tb.vcd -o system_top.fsdb`

3. **"Missing source files"**

   - Verify all paths in `system_top_src.f` are correct
   - Check files exist relative to `power/` directory
   - Update paths if your directory structure is different

4. **Synthesis fails with timing violations**

   - This is normal for initial run
   - Check `results/report_violations.txt` for details
   - Adjust clock periods in `sdc/clocks.sdc` if needed
   - Script will report maximum achievable frequency

5. **Library files not found**
   - Update `LIBS_PATH` and `CLTRLS_PATH` in `config.tcl`
   - Ensure you have access to 45nm CMOS libraries
   - Contact your CAD admin for library locations

## Customization

### Changing Clock Frequencies

Edit `sdc/clocks.sdc`:

```tcl
# For faster CPU clock (e.g., 100 MHz = 10 ns)
create_clock -name cpu_clk -period 10.0 [get_ports cpu_clk]

# For faster network clock (e.g., 200 MHz = 5 ns)
create_clock -name net_clk -period 5.0 [get_ports net_clk]
```

### Analyzing Different Mesh Sizes

If you scale up to 4×4 or 8×8 mesh:

1. Update `system_top_src.f` (no changes needed if using same modules)
2. Regenerate FSDB with larger mesh testbench
3. Synthesis will automatically handle larger design
4. Expect longer runtime and higher resource usage

### Adding More Neurons Per Bank

If `NUM_NEURONS_PER_BANK` changes:

1. No script changes needed (parameterized design)
2. Regenerate FSDB with new configuration
3. Results will scale proportionally

## Expected Runtime

On a modern server (8 cores):

- **RTL Analysis (rtla.tcl)**: 2-4 hours

  - Design elaboration: 5-10 minutes
  - RTL optimization: 1-3 hours
  - Report generation: 10-20 minutes

- **Power Analysis (restore_new.tcl)**: 30-60 minutes
  - FSDB processing: 10-15 minutes
  - Power computation: 15-30 minutes
  - Hierarchical reports: 5-15 minutes

**Total**: ~3-5 hours for complete analysis

## Output Interpretation

### Power Distribution (Typical)

- **Routers**: 30-40% (crossbar switching, buffers)
- **Network Interfaces**: 15-25% (CDC FIFOs, protocol conversion)
- **Neuron Banks**: 25-35% (FPU operations, computation)
- **Clock Tree**: 10-15% (clock distribution network)

### Critical Path (Typical)

- Usually through FPU (multiplication or addition-subtraction)
- Router crossbar may also be critical
- Look in `report_timing_critical_path.txt` for exact path

## References

### Related Files

- `../cpu/system_top.v` - Top-level RTL
- `../cpu/SYSTEM_TOP_README.md` - Architecture documentation
- `../cpu/testbench/system_top_tb.v` - Testbench for waveform generation

### Synopsys Documentation

- DC User Guide: Synthesis flow and optimization
- PrimeTime User Guide: Power analysis methodology
- TLU+ Format: Parasitic modeling

## Contact

For issues with:

- **Scripts**: Check this README and script comments
- **Technology files**: Contact your CAD/IT administrator
- **Design bugs**: See `../cpu/SYSTEM_TOP_README.md`

---

**Note**: This analysis uses 45nm CMOS technology for academic research purposes. For actual fabrication, consult with foundry and update technology files accordingly.
