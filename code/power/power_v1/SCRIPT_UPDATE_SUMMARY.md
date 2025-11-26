# script.sh Update Summary

## Overview

Updated `script.sh` automation script to align with the working System Top design (`system_top.v`) instead of the incomplete CPU-integrated design.

**Date**: 2025
**Design Target**: System Top - 2×2 Mesh NoC with Neuron Banks
**Status**: ALL 6 TESTS PASSING (100%)

---

## Changes Made

### 1. Path Variable Updates

#### Line 132 - Primary Path Variable

**Before:**

```bash
RTL_BLACKBOX_PATH="../../../../rtl/neuron_accelerator"
```

**After:**

```bash
RTL_SYSTEM_TOP_PATH="../cpu"
```

**Reason**: Points to the correct location of the working System Top design relative to the power/ directory.

---

### 2. Environment Metadata Updates

#### Line 184 - Environment Information Section

**Before:**

```bash
RTL_BLACKBOX_PATH: $RTL_BLACKBOX_PATH
```

**After:**

```bash
RTL_SYSTEM_TOP_PATH: $RTL_SYSTEM_TOP_PATH
```

**Reason**: Updated variable reference in run metadata file generation.

---

### 3. Directory Existence Checks

#### Lines 228-233 - Directory Structure Verification

**Before:**

```bash
Blackbox Directory Exists: $([ -d "$RTL_BLACKBOX_PATH" ] && echo "Yes" || echo "No")
```

**After:**

```bash
System Top Directory Exists: $([ -d "$RTL_SYSTEM_TOP_PATH" ] && echo "Yes" || echo "No")
System Top Source Exists: $([ -f "$RTL_SYSTEM_TOP_PATH/system_top.v" ] && echo "Yes" || echo "No")
System Top Testbench Exists: $([ -f "$RTL_SYSTEM_TOP_PATH/testbench/system_top_tb.v" ] && echo "Yes" || echo "No")
```

**Reason**:

- Updated variable reference
- Added explicit checks for system_top.v and testbench existence
- Provides better validation before execution

---

### 4. Metadata File Header

#### Line 200 - Run Metadata Header

**Before:**

```bash
# Blackbox Design Synthesis and Power Analysis Run Metadata
# ==========================================================
```

**After:**

```bash
# System Top (2x2 Mesh NoC) Synthesis and Power Analysis Run Metadata
# =====================================================================
```

**Reason**: Updated to reflect actual design being analyzed.

---

### 5. Script Banner

#### Line 248 - Main Script Banner

**Before:**

```bash
echo "========== Blackbox Design Synthesis and Power Analysis =========="
```

**After:**

```bash
echo "========== System Top (2x2 Mesh NoC) Synthesis and Power Analysis =========="
```

**Reason**: Updated to match actual design name and architecture.

---

### 6. VCS Compilation Section (STEP 1)

#### Lines 304-318 - VCS Compile Step

**Before:**

```bash
# Step 1: VCS Compile (for blackbox design)
if [ "$RUN_VCS" = true ]; then
    echo "========== STEP 1: VCS Compile (Blackbox) =========="
    if [ -d "$RTL_BLACKBOX_PATH" ]; then
        pushd "$RTL_BLACKBOX_PATH" > /dev/null
        vcs -sverilog -full64 -kdb -debug_access+all neuron_accelerator_tb.v +vcs+fsdbon -o simv | tee "../../synopsys/primepower/tech_45nCMOS/neuron_accelerator/$TEMP_RESULTS_DIR/vcs_compile.log"
        echo "VCS compilation completed successfully"
        popd > /dev/null
    else
        echo "Warning: Blackbox RTL directory not found, skipping VCS compilation"
    fi
```

**After:**

```bash
# Step 1: VCS Compile (for System Top design)
if [ "$RUN_VCS" = true ]; then
    echo "========== STEP 1: VCS Compile (System Top) =========="
    if [ -d "$RTL_SYSTEM_TOP_PATH" ]; then
        pushd "$RTL_SYSTEM_TOP_PATH" > /dev/null
        echo "Compiling System Top (2x2 Mesh NoC with Neuron Banks)..."
        vcs -sverilog -full64 -kdb -debug_access+all testbench/system_top_tb.v -f ../power/system_top_src.f +vcs+fsdbon -o simv | tee "../power/$TEMP_RESULTS_DIR/vcs_compile.log"
        echo "VCS compilation completed successfully"
        popd > /dev/null
    else
        echo "Warning: System Top RTL directory not found, skipping VCS compilation"
    fi
```

**Key Changes**:

- Updated path variable: `RTL_BLACKBOX_PATH` → `RTL_SYSTEM_TOP_PATH`
- Changed testbench: `neuron_accelerator_tb.v` → `testbench/system_top_tb.v`
- Added source file list: `-f ../power/system_top_src.f` (includes all 70+ required modules)
- Updated log path to be relative to power/ directory
- Added descriptive echo message
- Updated warning message

---

### 7. Simulation Section (STEP 2)

#### Lines 320-327 - Run Simulation Step

**Before:**

```bash
if [ "$RUN_SIMV" = true ]; then
    echo "========== STEP 2: Run Simulation =========="
    if [ -d "$RTL_BLACKBOX_PATH" ]; then
        pushd "$RTL_BLACKBOX_PATH" > /dev/null
```

**After:**

```bash
if [ "$RUN_SIMV" = true ]; then
    echo "========== STEP 2: Run Simulation =========="
    if [ -d "$RTL_SYSTEM_TOP_PATH" ]; then
        pushd "$RTL_SYSTEM_TOP_PATH" > /dev/null
```

**Reason**: Updated path variable for simulation step.

#### Line 327 - Simulation Warning

**Before:**

```bash
echo "Warning: Blackbox RTL directory not found, skipping simulation"
```

**After:**

```bash
echo "Warning: System Top RTL directory not found, skipping simulation"
```

**Reason**: Updated warning message to reflect correct design name.

---

## Summary of Changes

| Category            | Changes                                | Impact                                        |
| ------------------- | -------------------------------------- | --------------------------------------------- |
| **Path Variables**  | 1 primary variable renamed and updated | Points to correct RTL directory               |
| **Headers/Banners** | 2 updated                              | Reflects actual design name                   |
| **VCS Compilation** | Testbench, source list, paths updated  | Compiles correct design with all dependencies |
| **Simulation**      | Path variable updated                  | Runs correct simulation                       |
| **Metadata**        | Variable references updated            | Accurate run information                      |
| **Validation**      | Enhanced directory checks              | Better pre-execution verification             |

**Total Lines Modified**: ~12 sections across 433-line script

---

## Verification

### Script Syntax Check

```bash
bash -n script.sh
# Should return no errors
```

### Variable Verification

The script now uses:

- `RTL_SYSTEM_TOP_PATH="../cpu"` - Points to system_top.v location
- Testbench: `testbench/system_top_tb.v` - Verified working (6/6 tests pass)
- Source list: `../power/system_top_src.f` - Contains all 70+ required modules

### Consistency Check

All updated components align with:

- ✅ `config.tcl` - DESIGN_NAME = "system_top"
- ✅ `system_top_src.f` - Correct module paths
- ✅ `clocks.sdc` - system_top.v port names
- ✅ `restore_new.tcl` - Design description
- ✅ `tz_setup.tcl` - Status information

---

## Usage

The updated script maintains the same command-line interface:

### Full Synthesis and Power Analysis

```bash
./script.sh --all "Complete power analysis run"
```

### Individual Steps

```bash
# VCS compilation only
./script.sh --vcs "Compile System Top"

# RTL synthesis only
./script.sh --rtla "Synthesize System Top"

# Power analysis only
./script.sh --primepower "Power analysis of System Top"
```

### Step Combinations

```bash
# Compile and simulate
./script.sh --vcs --simv "Test System Top"

# Synthesis and power analysis
./script.sh --rtla --primepower "Synthesis and power run"
```

---

## Expected Output Structure

After running `./script.sh --all`:

```
synopsys/primepower/tech_45nCMOS/neuron_accelerator/
├── results_YYYYMMDD_HHMMSS/
│   ├── metadata.txt
│   ├── vcs_compile.log
│   ├── simulation.log
│   ├── rtl_synthesis.log
│   ├── power_analysis.log
│   └── final_results.log
```

---

## Related Files

This update completes the power analysis configuration along with:

1. **config.tcl** - Design name, file list, FSDB paths
2. **system_top_src.f** - Complete module source list (70+ files)
3. **clocks.sdc** - Timing constraints with correct port names
4. **restore_new.tcl** - Power analysis setup script
5. **tz_setup.tcl** - Design setup with verification status
6. **script.sh** - This automation script (NOW UPDATED)

All 6 files now consistently target the working `system_top.v` design.

---

## Notes

### Design Status

- **system_top.v**: WORKING - ALL 6 TESTS PASSING (100%)
- **system_top_with_cpu.v**: INCOMPLETE - Parameter mismatches

### Why Use system_top.v?

The system_top.v design is fully verified and functional. While system_top_with_cpu.v represents the final architecture with integrated CPUs, it has module interface mismatches that need to be resolved. For power analysis validation, we use the working design first.

### Next Steps

1. Run power analysis on working system_top.v
2. Validate power analysis flow
3. Fix system_top_with_cpu.v module interfaces
4. Re-run power analysis on complete CPU-integrated design

---

## Testing Checklist

Before running the script:

- [ ] Verify `RTL_SYSTEM_TOP_PATH` points to correct directory
- [ ] Check `system_top.v` exists at `$RTL_SYSTEM_TOP_PATH/system_top.v`
- [ ] Check `system_top_tb.v` exists at `$RTL_SYSTEM_TOP_PATH/testbench/system_top_tb.v`
- [ ] Verify `system_top_src.f` contains all required modules
- [ ] Ensure VCS and Synopsys tools are in PATH
- [ ] Verify NangateOpenCellLibrary is accessible

After running:

- [ ] Check for successful VCS compilation
- [ ] Verify simulation runs without errors
- [ ] Review synthesis reports in LIB/ directory
- [ ] Check power analysis results
- [ ] Validate FSDB file generation

---

**Update Complete**: script.sh now fully configured for System Top power analysis
