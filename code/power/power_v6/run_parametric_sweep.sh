#!/bin/bash

# =============================================================================
# Parametric Sweep Script for NoC Mesh Power Analysis
# =============================================================================
# Description: Automates power analysis across different mesh configurations
# Author: CO502 Group 1
# Usage: ./run_parametric_sweep.sh
# =============================================================================

# Exit on any error
set -e
trap 'cleanup_on_error' ERR

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration arrays
MESH_SIZES=(2 3 4 5)           # 2x2, 3x3, 4x4, 5x5
NEURON_COUNTS=(4 8 16 32)      # Different neuron counts per node

# Design name for power extraction
DESIGN_NAME="mesh"

# Master results directory
MASTER_RESULTS_DIR="parametric_results_$(date +"%Y%m%d_%H%M%S")"
mkdir -p "$MASTER_RESULTS_DIR"

# Summary file
SUMMARY_FILE="$MASTER_RESULTS_DIR/power_summary.csv"
echo "Configuration,Rows,Cols,Neurons,Total_Nodes,Total_Neurons,Total_Power(W),Int_Power(W),Switch_Power(W),Leak_Power(W),Status,Timestamp,Duration(s)" > "$SUMMARY_FILE"

# Function to cleanup on error
cleanup_on_error() {
    echo -e "${RED}========== ERROR OCCURRED ==========${NC}"
    echo "Execution failed at $(date)"
    echo "Check logs in: $MASTER_RESULTS_DIR"
    exit 1
}

# Function to print colored messages
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to extract power values from report
extract_power_from_report() {
    local report_file="$1"
    local output_var="$2"
    
    if [ -f "$report_file" ]; then
        # Extract the main design power line
        local power_line=$(grep "^$DESIGN_NAME " "$report_file" | head -1)
        if [ -n "$power_line" ]; then
            # Parse: design_name Int Switch Leak Total %
            local int_power=$(echo "$power_line" | awk '{print $2}')
            local switch_power=$(echo "$power_line" | awk '{print $3}')
            local leak_power=$(echo "$power_line" | awk '{print $4}')
            local total_power=$(echo "$power_line" | awk '{print $5}')
            
            eval "$output_var=\"$total_power,$int_power,$switch_power,$leak_power\""
            return 0
        fi
    fi
    
    eval "$output_var=\"N/A,N/A,N/A,N/A\""
    return 1
}

# Function to update testbench parameters
update_testbench_params() {
    local rows=$1
    local cols=$2
    local neurons=$3
    local tb_file="../../accelerator/mesh/mesh_tb.v"
    
    print_warning "Updating testbench: ROWS=$rows, COLS=$cols, NEURONS=$neurons"
    
    # Create backup
    cp "$tb_file" "${tb_file}.backup"
    
    # Update parameters using sed
    sed -i "s/parameter ROWS = [0-9]\+;/parameter ROWS = $rows;/" "$tb_file"
    sed -i "s/parameter COLS = [0-9]\+;/parameter COLS = $cols;/" "$tb_file"
    sed -i "s/parameter NUM_NEURONS = [0-9]\+;/parameter NUM_NEURONS = $neurons;/" "$tb_file"
    
    print_success "Testbench parameters updated"
}

# Function to restore testbench backup
restore_testbench() {
    local tb_file="../../accelerator/mesh/mesh_tb.v"
    if [ -f "${tb_file}.backup" ]; then
        mv "${tb_file}.backup" "$tb_file"
        print_success "Testbench restored from backup"
    fi
}

# Function to run single configuration
run_configuration() {
    local rows=$1
    local cols=$2
    local neurons=$3
    local config_name="${rows}x${cols}_N${neurons}"
    local total_nodes=$((rows * cols))
    local total_neurons=$((total_nodes * neurons))
    
    print_header "Configuration: $config_name"
    echo "  Mesh Size: ${rows}x${cols} = $total_nodes nodes"
    echo "  Neurons per Node: $neurons"
    echo "  Total Neurons: $total_neurons"
    
    local start_time=$(date +%s)
    local config_dir="$MASTER_RESULTS_DIR/${config_name}"
    mkdir -p "$config_dir"
    
    # Update testbench parameters
    update_testbench_params $rows $cols $neurons
    
    # Export configuration as environment variables
    export CONFIG_ROWS=$rows
    export CONFIG_COLS=$cols
    export CONFIG_NEURONS=$neurons
    export TEMP_RESULTS_DIR="$config_dir"
    
    # Create configuration metadata
    cat > "$config_dir/config_info.txt" << EOF
Configuration: $config_name
Timestamp: $(date)
Mesh Dimensions: ${rows}x${cols}
Neurons per Node: $neurons
Total Nodes: $total_nodes
Total Neurons: $total_neurons
EOF
    
    # Run the synthesis and power analysis
    # Output goes to both terminal (via tee) and log file
    local status="FAILED"
    if ./script.sh "Parametric sweep: $config_name" 2>&1 | tee "$config_dir/run.log"; then
        status="SUCCESS"
        print_success "Configuration $config_name completed successfully"
        
        # Extract power values
        local power_report="$config_dir/report_power.txt"
        local power_values
        if extract_power_from_report "$power_report" power_values; then
            print_success "Power values extracted: $power_values W"
        else
            power_values="N/A,N/A,N/A,N/A"
            print_warning "Could not extract power values from report"
        fi
    else
        print_error "Configuration $config_name FAILED - check $config_dir/run.log"
        power_values="N/A,N/A,N/A,N/A"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Restore testbench
    restore_testbench
    
    # Append to summary CSV
    echo "$config_name,$rows,$cols,$neurons,$total_nodes,$total_neurons,$power_values,$status,$(date),${duration}" >> "$SUMMARY_FILE"
    
    print_success "Duration: ${duration}s"
    echo ""
}

# Main execution
print_header "NoC Mesh Parametric Power Analysis Sweep"
echo "Starting at: $(date)"
echo "Master results directory: $MASTER_RESULTS_DIR"
echo ""

# Create initial backup of testbench
cp "../../accelerator/mesh/mesh_tb.v" "../../accelerator/mesh/mesh_tb.v.original"

# Configuration counter
total_configs=0
successful_configs=0
failed_configs=0

# Run all configurations
for size in "${MESH_SIZES[@]}"; do
    for neurons in "${NEURON_COUNTS[@]}"; do
        total_configs=$((total_configs + 1))
        
        if run_configuration $size $size $neurons; then
            successful_configs=$((successful_configs + 1))
        else
            failed_configs=$((failed_configs + 1))
        fi
        
        # Add delay between runs to avoid resource conflicts
        sleep 2
    done
done

# Restore original testbench
if [ -f "../../accelerator/mesh/mesh_tb.v.original" ]; then
    mv "../../accelerator/mesh/mesh_tb.v.original" "../../accelerator/mesh/mesh_tb.v"
    print_success "Original testbench restored"
fi

# Generate final report
print_header "Parametric Sweep Complete"
echo "Total Configurations: $total_configs"
echo "Successful: $successful_configs"
echo "Failed: $failed_configs"
echo ""
echo "Results saved in: $MASTER_RESULTS_DIR"
echo "Summary CSV: $SUMMARY_FILE"
echo ""

# Create a human-readable summary
READABLE_SUMMARY="$MASTER_RESULTS_DIR/SUMMARY.txt"
cat > "$READABLE_SUMMARY" << EOF
===============================================================================
NoC Mesh Parametric Power Analysis - Summary Report
===============================================================================
Generated: $(date)
Master Results Directory: $MASTER_RESULTS_DIR

Configuration Overview:
-----------------------
Total Configurations Tested: $total_configs
Successful: $successful_configs
Failed: $failed_configs

Mesh Sizes Tested: ${MESH_SIZES[@]}
Neuron Counts Tested: ${NEURON_COUNTS[@]}

Detailed Results:
-----------------
EOF

# Parse CSV and create readable table
echo "" >> "$READABLE_SUMMARY"
printf "%-15s %-20s %-15s %-15s %-10s\n" "Configuration" "Total Neurons" "Total Power(W)" "Status" "Duration" >> "$READABLE_SUMMARY"
printf "%-15s %-20s %-15s %-15s %-10s\n" "===============" "====================" "===============" "===============" "==========" >> "$READABLE_SUMMARY"

tail -n +2 "$SUMMARY_FILE" | while IFS=',' read -r config rows cols neurons nodes total_neurons total_power int_power switch_power leak_power status timestamp duration; do
    printf "%-15s %-20s %-15s %-15s %-10s\n" "$config" "$total_neurons" "$total_power" "$status" "${duration}s" >> "$READABLE_SUMMARY"
done

cat >> "$READABLE_SUMMARY" << EOF

===============================================================================
Files Generated:
===============================================================================
- power_summary.csv         : Machine-readable CSV with all power metrics
- SUMMARY.txt              : This human-readable summary
- <config_name>/           : Individual configuration results directories

Each configuration directory contains:
- config_info.txt          : Configuration metadata
- run.log                  : Complete execution log
- report_power.txt         : Detailed power report
- rtl_synthesis.log        : Synthesis log
- power_restore.log        : Power analysis log
- And other detailed reports...

===============================================================================
EOF

print_success "Human-readable summary created: $READABLE_SUMMARY"

# Display summary on screen
cat "$READABLE_SUMMARY"

echo ""
print_header "All Configurations Complete!"
echo "Check detailed results in: $MASTER_RESULTS_DIR"
