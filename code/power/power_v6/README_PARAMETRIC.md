# NoC Mesh Parametric Power Analysis - power_v6

## Overview
This directory contains automated scripts for parametric power analysis across different mesh configurations.

## Quick Start

### 1. Run Complete Parametric Sweep
```bash
chmod +x run_parametric_sweep.sh
./run_parametric_sweep.sh
```

This will automatically test all combinations of:
- **Mesh Sizes**: 2x2, 3x3, 4x4, 5x5
- **Neuron Counts**: 4, 8, 16, 32 neurons per node

Total configurations tested: **16** (4 mesh sizes × 4 neuron counts)

### 2. Run Single Configuration (Quick Test)
```bash
chmod +x run_single_config.sh
./run_single_config.sh <rows> <cols> <neurons>

# Example: Test 3x3 mesh with 8 neurons per node
./run_single_config.sh 3 3 8
```

### 3. Analyze Results
```bash
python3 analyze_results.py parametric_results_<timestamp>
```

This generates:
- Power vs neurons plots
- Power breakdown charts
- Efficiency heatmaps
- Comparison tables (TXT and Excel)

## Configuration Customization

### Modify Test Configurations
Edit `run_parametric_sweep.sh`:

```bash
# Line 17-18: Change mesh sizes and neuron counts
MESH_SIZES=(2 3 4 5)           # Add/remove mesh dimensions
NEURON_COUNTS=(4 8 16 32)      # Add/remove neuron counts
```

Example - Test only 2x2 and 4x4 with 8 and 16 neurons:
```bash
MESH_SIZES=(2 4)
NEURON_COUNTS=(8 16)
```

## Output Structure

```
parametric_results_<timestamp>/
├── power_summary.csv              # Machine-readable results
├── SUMMARY.txt                    # Human-readable summary
├── 2x2_N4/                       # Individual config results
│   ├── config_info.txt
│   ├── run.log
│   ├── report_power.txt
│   ├── rtl_synthesis.log
│   └── power_restore.log
├── 2x2_N8/
├── 3x3_N4/
└── ...
```

## Results Analysis

### CSV Format (power_summary.csv)
```csv
Configuration,Rows,Cols,Neurons,Total_Nodes,Total_Neurons,Total_Power(W),Int_Power(W),Switch_Power(W),Leak_Power(W),Status,Timestamp,Duration(s)
2x2_N4,2,2,4,4,16,0.1234,0.0456,0.0678,0.0100,SUCCESS,2025-12-09,127
```

### Visualization Outputs
After running `analyze_results.py`:
- `power_vs_neurons.png` - Power scaling with neuron count
- `power_breakdown.png` - Internal/Switching/Leakage breakdown
- `power_heatmap.png` - 2D heatmap of configurations
- `power_efficiency.png` - Power per neuron comparison
- `comparison_table.txt` - Detailed comparison table

## Workflow

```
┌─────────────────────────────────┐
│  run_parametric_sweep.sh        │
│  (Main automation script)        │
└──────────┬──────────────────────┘
           │
           ├─► Update mesh_tb.v parameters
           │   (ROWS, COLS, NUM_NEURONS)
           │
           ├─► Run script.sh
           │   ├─► VCS Compile & Simulate
           │   ├─► RTL Synthesis (rtl_shell)
           │   └─► Power Analysis (pwr_shell)
           │
           ├─► Extract power values
           │
           └─► Save to CSV and individual dirs
                     │
                     ▼
           ┌─────────────────────┐
           │  analyze_results.py  │
           │  (Post-processing)   │
           └─────────────────────┘
```

## Troubleshooting

### Script Permission Errors
```bash
chmod +x run_parametric_sweep.sh run_single_config.sh
```

### Python Dependencies
```bash
pip3 install pandas matplotlib seaborn openpyxl
```

### Testbench Restore
If interrupted, manually restore:
```bash
cd ../../accelerator/mesh
mv mesh_tb.v.original mesh_tb.v
```

### Failed Configurations
Check individual run logs:
```bash
cat parametric_results_<timestamp>/<config_name>/run.log
```

## Performance Tips

1. **Parallel Execution**: The script runs configurations sequentially. For faster results on multi-core systems, modify the script to run multiple configs in parallel (with resource management).

2. **Partial Runs**: Comment out unwanted configurations in the arrays to test subsets.

3. **Skip Simulation**: If simulation files already exist, you can comment out the VCS steps in `script.sh` to speed up reruns.

## Example Usage

### Full Sweep (All Configs)
```bash
./run_parametric_sweep.sh
# Wait ~30-60 minutes depending on configurations
python3 analyze_results.py parametric_results_20251209_120000
```

### Quick Test (Single Config)
```bash
./run_single_config.sh 2 2 4  # Quick 2x2 test with 4 neurons
```

### Custom Sweep (Only Large Meshes)
Edit script:
```bash
MESH_SIZES=(4 5)              # Only 4x4 and 5x5
NEURON_COUNTS=(16 32)         # Only high neuron counts
```

## Integration with Git

The parametric sweep script does NOT auto-commit by default. To enable:
```bash
# At the end of run_parametric_sweep.sh, add:
git add parametric_results_*
git commit -m "Parametric sweep results"
git push
```

## Notes

- Original testbench is automatically backed up and restored
- Each run is timestamped to prevent overwrites
- Failed runs are logged with full error details
- Power values are extracted from synthesis reports
- Duration tracking helps identify slow configurations

## Support

For issues or questions:
1. Check individual run logs in the config directories
2. Verify testbench parameters are restored correctly
3. Ensure all paths in `config.tcl` are correct
4. Check synthesis tool availability (`rtl_shell`, `pwr_shell`)
