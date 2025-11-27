#!/bin/tcsh -f
# =============================================================================
# Power Analysis and Metrics Reporting Script for 45nm CMOS
# =============================================================================
# Description: This script performs detailed power analysis and generates
#              comprehensive power and RTL metrics reports for the Blackbox design
# Author: Neuromorphic Accelerator Team  
# Technology: 45nm CMOS Process
# Prerequisites: Run after rtla.tcl synthesis completion
# =============================================================================

# Load shared configuration
source config.tcl

# -----------------------------------------------------------------------------
# Power Analysis Configuration
# -----------------------------------------------------------------------------
puts "========== Starting Power Analysis and Metrics =========="
puts "Technology: 45nm CMOS"
puts "Design: Blackbox Neuromorphic Accelerator"

# Enable power analysis features
set_app_var power_enable_rtl_analysis true
set_app_var power_enable_analysis true
set_app_var power_enable_new_rrm_view true

# Configure parallel processing
set_host_options -max_cores $CORES
puts "Using $CORES cores for power analysis"

# Create temp results directory if it doesn't exist
file mkdir $TEMP_RESULTS_DIR

# -----------------------------------------------------------------------------
# Load and Process Power Data
# -----------------------------------------------------------------------------
puts "Loading power data and computing metrics..."

# Read design data from synthesis workspace
read_design_data $OUTPUT_DIR

# Read FSDB waveform data
read_fsdb -strip_path $STRIP_PATH $FSDB_FILE

# Process power data
read_name_mapping
update_power
update_metrics

puts "Power data loaded and processed successfully"

# -----------------------------------------------------------------------------
# Power Reports Generation
# -----------------------------------------------------------------------------
puts "========== Generating Power Reports =========="

# Group-based power consumption reports
puts "Generating group-based power reports..."
report_power -group register > "$TEMP_RESULTS_DIR/power_register.txt"
report_power -group sequential > "$TEMP_RESULTS_DIR/power_sequential.txt"
report_power -group combinational > "$TEMP_RESULTS_DIR/power_combinational.txt"
report_power -group black_box > "$TEMP_RESULTS_DIR/power_black_box.txt"
report_power -group io_pad > "$TEMP_RESULTS_DIR/power_io_pad.txt"

# Hierarchical power reports at different levels
puts "Generating hierarchical power reports..."
foreach level $HIERARCHY_LEVELS {
    report_power -hierarchy -levels $level -verbose > "$TEMP_RESULTS_DIR/power_by_module_${level}.txt"
}

# Overall power summary
report_power > "$TEMP_RESULTS_DIR/power_summary.txt"

# -----------------------------------------------------------------------------
# RTL Metrics Reports
# -----------------------------------------------------------------------------
puts "========== Generating RTL Metrics Reports =========="

# RTL metrics overview
report_rtl_metrics -list > "$TEMP_RESULTS_DIR/rtl_metrics_list.txt"

# Hierarchical RTL metrics
report_rtl_metrics -view hier \
    -hier_attributes {gated_registers icg_cells latch_cells reg_cells sequential_cells combinational_cells total_power} \
    > "$TEMP_RESULTS_DIR/rtl_metrics_hier.txt"

# Register-level RTL metrics
report_rtl_metrics -view register \
    -reg_attributes {dynamic_power switching_power leakage_power total_power register_gated root_clk_name} \
    > "$TEMP_RESULTS_DIR/rtl_metrics_register.txt"

puts "========== Power Analysis and Metrics Complete =========="
puts "All reports generated in: $TEMP_RESULTS_DIR"

exit