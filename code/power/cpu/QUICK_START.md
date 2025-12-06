# Quick Start Guide - CPU Power Analysis

## Fixed Issues
✅ Removed `include` statement from cpu_tb.v (using -f file list instead)  
✅ Fixed VCS compilation path (runs from `code/cpu` directory)  
✅ Fixed FSDB generation path (generates at `code/cpu/cpu/cpu_tb.fsdb`)  
✅ Updated src_detailed.f with relative paths and proper space escaping  
✅ Removed invalid `+vcs+fsdb+delta=on` option  

## Run Power Analysis

### From the remote machine:

```bash
cd code/power/cpu
./script.sh "Initial CPU power characterization"
```

## What Happens:

1. **VCS Compilation** (from `code/cpu` directory)
   - Compiles all CPU modules using `src_detailed.f`
   - Creates `simv` executable
   - Enables FSDB dumping with `+define+FSDB`

2. **Simulation**
   - Runs testbench with 30 instruction tests
   - Generates `cpu/cpu_tb.fsdb` for power analysis
   - Generates `cpu/cpu_tb.vcd` for waveform viewing

3. **RTL Synthesis** (with rtl_shell)
   - Synthesizes CPU for SKY130 130nm
   - Optimizes for frequency
   - Generates timing reports

4. **Power Analysis** (with pwr_shell)
   - Reads FSDB switching activity
   - Correlates with synthesized netlist
   - Generates detailed power reports

## Expected Output:

```
results/
└── <timestamp>/
    ├── vcs_compile.log       # VCS compilation log
    ├── simulation.log        # Testbench execution log
    ├── rtla.log             # Synthesis log
    ├── restore_new.log      # Power analysis log
    ├── power_summary_detailed.txt
    ├── power_by_module_*.txt
    ├── rtl_metrics_*.txt
    └── publication_summary.txt
```

## Key Files:

- **cpu/cpu/cpu_tb.v** - Testbench (30 test cases, FSDB dumping)
- **cpu/cpu/cpu_tb.fsdb** - Switching activity database (generated)
- **power/cpu/src_detailed.f** - Complete source file list
- **power/cpu/config.tcl** - Shared configuration
- **power/cpu/script.sh** - Main execution script

## Troubleshooting:

### If VCS compilation fails:
```bash
cd code/cpu
vcs -sverilog -full64 -kdb -debug_access+all +lint=TFIPC-L \
    -timescale=1ns/1ps -f ../power/cpu/src_detailed.f \
    +vcs+fsdbon +define+FSDB -o simv
```

### If simulation fails:
```bash
cd code/cpu
./simv +fsdbfile+cpu_tb.fsdb
ls -lh cpu/cpu_tb.fsdb  # Check FSDB generated
```

### View waveforms:
```bash
cd code/cpu/cpu
gtkwave cpu_tb.vcd       # For GTKWave
# or
verdi -ssf cpu_tb.fsdb   # For Verdi (commercial)
```

## File Paths Reference:

From `power/cpu/script.sh` working directory:
- CPU RTL: `../../cpu/` 
- Testbench: `../../cpu/cpu/cpu_tb.v`
- FSDB output: `../../cpu/cpu/cpu_tb.fsdb`
- Source list: `../power/cpu/src_detailed.f`

VCS runs from `code/cpu/` directory, so src_detailed.f uses relative paths from there.

## Notes:

- VCS requires license (warning about 26-day expiration is normal)
- FSDB generation requires Verdi license
- Simulation takes ~5-10 minutes
- Synthesis takes ~10-20 minutes
- Power analysis takes ~5 minutes
- Total runtime: ~20-40 minutes

## Success Indicators:

✅ `VCS compilation completed successfully`  
✅ `FSDB file generated successfully: cpu/cpu_tb.fsdb`  
✅ `Simulation completed successfully`  
✅ `RTL analysis completed successfully`  
✅ `Power analysis completed successfully`  

Results saved in: `power/cpu/results/<timestamp>/`
