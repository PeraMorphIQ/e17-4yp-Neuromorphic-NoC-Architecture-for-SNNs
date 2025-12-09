#!/bin/bash
# Quick Reference Guide for Parametric Power Analysis

cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║         NoC Mesh Parametric Power Analysis - Quick Guide         ║
╚══════════════════════════════════════════════════════════════════╝

📋 AVAILABLE COMMANDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣  Run Full Parametric Sweep (All Configurations)
   ./run_parametric_sweep.sh
   
   Tests: 2x2, 3x3, 4x4, 5x5 meshes
   With: 4, 8, 16, 32 neurons per node
   Total: 16 configurations
   Duration: ~30-60 minutes

2️⃣  Test Single Configuration (Quick Test)
   ./run_single_config.sh <rows> <cols> <neurons>
   
   Examples:
     ./run_single_config.sh 2 2 4    # 2x2 mesh, 4 neurons
     ./run_single_config.sh 3 3 8    # 3x3 mesh, 8 neurons
     ./run_single_config.sh 4 4 16   # 4x4 mesh, 16 neurons
   
   Duration: ~2-5 minutes per config

3️⃣  Analyze Results (Generate Plots & Tables)
   python3 analyze_results.py parametric_results_YYYYMMDD_HHMMSS
   
   Generates:
     • Power vs neurons plots
     • Power breakdown charts
     • Efficiency heatmaps
     • Comparison tables

4️⃣  Original Single Run (Manual Description)
   ./script.sh "Your description here"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚙️  CONFIGURATION OPTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Edit run_parametric_sweep.sh to customize:

  MESH_SIZES=(2 3 4 5)           # Mesh dimensions to test
  NEURON_COUNTS=(4 8 16 32)      # Neurons per node to test

Examples:

  # Test only 2x2 and 4x4 meshes
  MESH_SIZES=(2 4)
  NEURON_COUNTS=(4 8 16 32)
  
  # Test high neuron counts only
  MESH_SIZES=(2 3 4 5)
  NEURON_COUNTS=(16 32 64)
  
  # Quick test with minimal configs
  MESH_SIZES=(2)
  NEURON_COUNTS=(4 8)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 OUTPUT FILES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

parametric_results_<timestamp>/
  ├── power_summary.csv           # All results in CSV format
  ├── SUMMARY.txt                 # Human-readable summary
  ├── 2x2_N4/                    # Results for 2x2 mesh, 4 neurons
  │   ├── config_info.txt
  │   ├── run.log
  │   ├── report_power.txt
  │   └── ...
  └── <config_name>/             # Results for each configuration

After running analyze_results.py:
  ├── power_vs_neurons.png        # Power scaling plots
  ├── power_breakdown.png         # Internal/Switching/Leakage
  ├── power_heatmap.png          # 2D configuration heatmap
  ├── power_efficiency.png       # Power per neuron
  └── comparison_table.txt        # Detailed comparison

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 TYPICAL WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1: Make scripts executable (first time only)
  chmod +x run_parametric_sweep.sh run_single_config.sh

Step 2: Test single configuration first
  ./run_single_config.sh 2 2 4

Step 3: If successful, run full sweep
  ./run_parametric_sweep.sh

Step 4: Analyze results
  python3 analyze_results.py parametric_results_YYYYMMDD_HHMMSS

Step 5: View results
  cd parametric_results_YYYYMMDD_HHMMSS
  cat SUMMARY.txt
  # Open PNG files to view plots

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 TROUBLESHOOTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Permission denied:
  chmod +x *.sh

Python modules missing:
  pip3 install pandas matplotlib seaborn openpyxl

Testbench not restored:
  cd ../../accelerator/mesh
  mv mesh_tb.v.original mesh_tb.v

Check failed configuration:
  cat parametric_results_*/FAILED/run.log

View individual config log:
  cat parametric_results_*/<config_name>/run.log

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📈 EXPECTED RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Configuration    Approx Power    Approx Time
─────────────────────────────────────────────
2x2 mesh, 4N     ~0.1-0.2W       2-3 min
3x3 mesh, 8N     ~0.3-0.5W       3-5 min
4x4 mesh, 16N    ~0.8-1.2W       5-8 min
5x5 mesh, 32N    ~2.0-3.0W       8-12 min

Full sweep (16 configs): 30-60 minutes total

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 TIPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Test single config first to verify setup
• Larger meshes take significantly longer
• Results are timestamped - no overwrites
• Original testbench is auto-backed up
• Failed runs are saved for debugging
• CSV file can be opened in Excel
• Plots require display/X11 forwarding

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 MORE INFO: See README_PARAMETRIC.md

╚══════════════════════════════════════════════════════════════════╝
EOF
