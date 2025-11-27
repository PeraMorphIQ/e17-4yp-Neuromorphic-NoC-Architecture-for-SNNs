#!/bin/bash
set -e
set -o pipefail

# Check if a purpose sentence is provided
if [ -z "$1" ]; then
    echo "Error: Please provide a sentence describing the purpose as an argument."
    echo "Usage: $0 \"<purpose sentence>\""
    exit 1
fi

# Store the purpose sentence
PURPOSE="$1"

# Prepare directories
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="results"
OLD_RESULTS_DIR="old_results"

# Step -1: Archive old results if they exist
if [ -d "$RESULTS_DIR" ]; then
    echo "========== Archiving old results =========="
    mkdir -p "$OLD_RESULTS_DIR"
    mv "$RESULTS_DIR" "$OLD_RESULTS_DIR/results_$TIMESTAMP"
    echo "Old results moved to $OLD_RESULTS_DIR/results_$TIMESTAMP"
fi

# Now create a fresh results directory
mkdir -p "$RESULTS_DIR"

# Save the purpose sentence
echo "$PURPOSE" > "$RESULTS_DIR/purpose.txt"

# Step 1: VCS Compile
echo "========== STEP 1: VCS Compile =========="
pushd "../../accelerator/mesh" > /dev/null
vcs -sverilog -full64 -kdb -debug_access+all -f ../../power/power_v2/mesh_sim.f mesh_tb.v +vcs+fsdbon -o simv | tee "../../power/power_v2/$RESULTS_DIR/vcs_compile.log"

# Step 2: Run Simulation
echo "========== STEP 2: Run Simulation =========="
./simv +fsdb+all=on +fsdb+delta | tee "../../power/power_v2/$RESULTS_DIR/simulation.log"
popd > /dev/null

# Check and optionally remove existing library and workspace directories
LIB_DIR="LIB"
WORK_DIR="RTLA_WORKSPACE"

if [ -d "$LIB_DIR" ]; then
    echo "Removing existing library directory '$LIB_DIR'..."
    rm -rf "$LIB_DIR"
fi

if [ -d "$WORK_DIR" ]; then
    echo "Removing existing workspace directory '$WORK_DIR'..."
    rm -rf "$WORK_DIR"
fi

echo "========== STEP 1: RTL Synthesis =========="
rtl_shell -f rtla.tcl | tee "$RESULTS_DIR/rtl_synthesis.log"

echo "========== STEP 2: Power Restoration =========="
pwr_shell -f restore_new.tcl | tee "$RESULTS_DIR/power_restore.log"

# Step 5: Git Commit and Push
echo "========== STEP 5: Git Commit and Push =========="
git add .
git commit -m "Auto commit: 45nm CMOS - $PURPOSE - $TIMESTAMP"
git pull --rebase --autostash origin main
git push

echo "========== All Steps Completed =========="
echo "Results and logs are saved in the '$RESULTS_DIR' folder."
