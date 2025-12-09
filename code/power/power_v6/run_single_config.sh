#!/bin/bash

# =============================================================================
# Quick Configuration Test Script
# =============================================================================
# Description: Test specific mesh configurations quickly
# Usage: ./run_single_config.sh <rows> <cols> <neurons>
# Example: ./run_single_config.sh 3 3 8
# =============================================================================

# Check arguments
if [ $# -ne 3 ]; then
    echo "Usage: $0 <rows> <cols> <neurons>"
    echo "Example: $0 3 3 8"
    echo ""
    echo "This will test a 3x3 mesh with 8 neurons per node"
    exit 1
fi

ROWS=$1
COLS=$2
NEURONS=$3

CONFIG_NAME="${ROWS}x${COLS}_N${NEURONS}"
TOTAL_NODES=$((ROWS * COLS))
TOTAL_NEURONS=$((TOTAL_NODES * NEURONS))

echo "=========================================="
echo "Testing Configuration: $CONFIG_NAME"
echo "=========================================="
echo "Mesh Size: ${ROWS}x${COLS} = $TOTAL_NODES nodes"
echo "Neurons per Node: $NEURONS"
echo "Total Neurons: $TOTAL_NEURONS"
echo ""

# Backup testbench
TB_FILE="../../accelerator/mesh/mesh_tb.v"
cp "$TB_FILE" "${TB_FILE}.backup"

# Update testbench parameters
echo "Updating testbench parameters..."
sed -i "s/parameter ROWS = [0-9]\+;/parameter ROWS = $ROWS;/" "$TB_FILE"
sed -i "s/parameter COLS = [0-9]\+;/parameter COLS = $COLS;/" "$TB_FILE"
sed -i "s/parameter NUM_NEURONS = [0-9]\+;/parameter NUM_NEURONS = $NEURONS;/" "$TB_FILE"

echo "✓ Parameters updated"
echo ""

# Run synthesis and power analysis
# Output shown directly in terminal (no redirection)
echo "Running synthesis and power analysis..."
echo "Output will be displayed in real-time..."
echo ""
./script.sh "Single config test: $CONFIG_NAME"

# Restore testbench
mv "${TB_FILE}.backup" "$TB_FILE"
echo "✓ Testbench restored"
echo ""
echo "=========================================="
echo "Configuration test complete!"
echo "=========================================="
