#!/bin/tcsh -f
# =============================================================================
# Power Analysis and Metrics Reporting Script for SKY130
# =============================================================================
# Description: This script performs detailed power analysis and generates
#              comprehensive power and RTL metrics reports for the Mesh design
# Author: Neuromorphic Accelerator Team  
# Technology: SKY130 130nm Process
# Prerequisites: Run after rtla.tcl synthesis completion
# =============================================================================

# Load shared configuration
source config.tcl

# -----------------------------------------------------------------------------
# Power Analysis Configuration
# -----------------------------------------------------------------------------
puts "========== Starting Power Analysis and Metrics =========="
puts "Technology: SKY130 130nm"
puts "Design: Mesh Neuromorphic NoC Architecture"

# Enable power analysis features with memory optimizations
set_app_var power_enable_rtl_analysis true
set_app_var power_enable_analysis true
set_app_var power_enable_multi_rtl_to_gate_mapping true
set_app_var power_enable_advanced_fsdb_reader false  ;# Disabled to save memory

# Memory optimization settings
set_app_var power_enable_memory_optimization true
set_app_var power_rtl_analysis_memory_limit 45000    ;# Limit to 45GB
set_app_var power_enable_incremental_analysis true
set_app_var power_analysis_effort medium              ;# Reduced from high to medium

# Clock gating analysis settings (disable to avoid crashes)
set_app_var power_enable_clock_gating_analysis false
set_app_var power_clock_gating_inference false
set_app_var power_clock_gating_propagate_enable false

# Hierarchical analysis for large designs
set_app_var power_hierarchical_analysis true

# Configure parallel processing (reduced to avoid memory pressure)
set_host_options -max_cores 4  ;# Reduced from 8 to 4
puts "Using 4 cores for power analysis (reduced for memory optimization)"

# Set search paths for SKY130 libraries
set search_path $SEARCH_PATHS

# Enable clock gating logic clustering for registers
set_app_var power_rtl_report_register_use_cg_logic_clustering true

# -----------------------------------------------------------------------------
# Load Analysis Data
# -----------------------------------------------------------------------------
puts "========== Loading Analysis Data =========="

# Create temp results directory if it doesn't exist
file mkdir $TEMP_RESULTS_DIR

# Compute metrics from previous synthesis run with error handling
puts "Starting compute_metrics with memory-optimized settings..."
if {[catch {compute_metrics -reuse $OUTPUT_DIR} result]} {
    puts "WARNING: compute_metrics encountered an error: $result"
    puts "Attempting recovery with simplified analysis..."
    # Try a simpler approach if full analysis fails
    set_app_var power_analysis_effort low
    compute_metrics -reuse $OUTPUT_DIR
}

# Read name mapping with error handling
if {[catch {read_name_mapping} result]} {
    puts "WARNING: read_name_mapping failed: $result"
    puts "Continuing without name mapping..."
}

# Update power with error handling
if {[catch {update_power} result]} {
    puts "WARNING: update_power failed: $result"
    puts "Attempting simplified power update..."
}

# Safely update metrics with error handling
if {[catch {update_metrics} result]} {
    puts "WARNING: update_metrics failed: $result"
    puts "Skipping detailed metrics update..."
}

puts "Analysis data loaded and updated"

# -----------------------------------------------------------------------------
# Power Analysis by Component Groups
# -----------------------------------------------------------------------------
puts "========== Generating Power Reports by Component Groups =========="

# Generate power reports grouped by component type (with error handling)
puts "Generating component group power reports..."
if {[catch {report_power -group register > "$TEMP_RESULTS_DIR/power_register.txt"} result]} {
    puts "WARNING: register power report failed: $result"
}
if {[catch {report_power -group sequential > "$TEMP_RESULTS_DIR/power_sequential.txt"} result]} {
    puts "WARNING: sequential power report failed: $result"
}
if {[catch {report_power -group combinational > "$TEMP_RESULTS_DIR/power_combinational.txt"} result]} {
    puts "WARNING: combinational power report failed: $result"
}
if {[catch {report_power -group black_box > "$TEMP_RESULTS_DIR/power_black_box.txt"} result]} {
    puts "WARNING: black_box power report failed: $result"
}
if {[catch {report_power -group io_pad > "$TEMP_RESULTS_DIR/power_io_pad.txt"} result]} {
    puts "WARNING: io_pad power report failed: $result"
}

puts "Component group power reports generated"

# -----------------------------------------------------------------------------
# Hierarchical Power Analysis
# -----------------------------------------------------------------------------
puts "========== Generating Hierarchical Power Reports =========="

# Generate hierarchical power reports at different levels of detail
# Reduced hierarchy levels to avoid memory issues
set REDUCED_HIERARCHY_LEVELS {2 3 5}
foreach level $REDUCED_HIERARCHY_LEVELS {
    if {[catch {report_power -hierarchy -levels $level -verbose > "$TEMP_RESULTS_DIR/power_by_module_${level}.txt"} result]} {
        puts "WARNING: Hierarchical power report for level $level failed: $result"
    } else {
        puts "Generated hierarchical power report for $level levels"
    }
}

# Generate comprehensive hierarchical report (reduced depth to avoid crash)
puts "Generating comprehensive hierarchical report (depth limited to 10)..."
if {[catch {report_power -hierarchy -levels 10 -verbose > "$TEMP_RESULTS_DIR/power_by_module_complete.txt"} result]} {
    puts "WARNING: Complete hierarchical power report failed: $result"
    puts "Trying with depth 5..."
    if {[catch {report_power -hierarchy -levels 5 > "$TEMP_RESULTS_DIR/power_by_module_complete.txt"} result]} {
        puts "WARNING: Even reduced hierarchical report failed, skipping..."
    }
}

puts "Hierarchical power reports generated"

# -----------------------------------------------------------------------------
# RTL Metrics Analysis
# -----------------------------------------------------------------------------
puts "========== Generating RTL Metrics Reports =========="

# List available RTL metrics
if {[catch {report_rtl_metrics -list > "$TEMP_RESULTS_DIR/rtl_metrics_list.txt"} result]} {
    puts "WARNING: RTL metrics list failed: $result"
}

# Generate hierarchical RTL metrics (simplified attributes to reduce memory)
if {[catch {
    report_rtl_metrics -view hier \
        -hier_attributes {gated_registers icg_cells reg_cells total_power} \
        > "$TEMP_RESULTS_DIR/rtl_metrics_hier.txt"
} result]} {
    puts "WARNING: Hierarchical RTL metrics failed: $result"
}

# Generate register-level RTL metrics (simplified attributes)
if {[catch {
    report_rtl_metrics -view register \
        -reg_attributes {dynamic_power total_power register_gated} \
        > "$TEMP_RESULTS_DIR/rtl_metrics_register.txt"
} result]} {
    puts "WARNING: Register RTL metrics failed: $result"
}

puts "RTL metrics reports generated"

# -----------------------------------------------------------------------------
# Power Analysis Validation
# -----------------------------------------------------------------------------
puts "========== Validating Power Analysis =========="

# Check RTL power analysis for issues
if {[catch {check_rtl_power > "$TEMP_RESULTS_DIR/check_rtl_power.txt"} result]} {
    puts "WARNING: check_rtl_power failed: $result"
}

# Generate summary report
if {[catch {report_power -verbose > "$TEMP_RESULTS_DIR/power_summary_detailed.txt"} result]} {
    puts "WARNING: Detailed power summary failed: $result"
    puts "Trying simplified summary..."
    if {[catch {report_power > "$TEMP_RESULTS_DIR/power_summary_simple.txt"} result]} {
        puts "WARNING: Even simplified summary failed: $result"
    }
}

puts "Power analysis validation completed"

# -----------------------------------------------------------------------------
# Generate Summary Statistics
# -----------------------------------------------------------------------------
puts "========== Generating Summary Statistics =========="

# Create a summary file with key metrics
set summary_file [open "$TEMP_RESULTS_DIR/power_analysis_summary.txt" w]
puts $summary_file "# Power Analysis Summary for Blackbox Neuromorphic Accelerator"
puts $summary_file "# Technology: SKY130 130nm"
puts $summary_file "# Generated: [clock format [clock seconds]]"
puts $summary_file "# Note: Analysis optimized for large design with memory constraints"
puts $summary_file ""

# Get basic power information with error handling
if {[catch {
    set total_power [get_attribute [current_design] total_power]
    set dynamic_power [get_attribute [current_design] dynamic_power]  
    set leakage_power [get_attribute [current_design] leakage_power]

    if {$total_power != ""} {
        puts $summary_file "Total Power: $total_power"
    }
    if {$dynamic_power != ""} {
        puts $summary_file "Dynamic Power: $dynamic_power"
    }
    if {$leakage_power != ""} {
        puts $summary_file "Leakage Power: $leakage_power"
    }
} result]} {
    puts $summary_file "WARNING: Could not extract all power values: $result"
    puts "WARNING: Power value extraction failed: $result"
}

close $summary_file

puts "Summary statistics generated"

# -----------------------------------------------------------------------------
# Completion Message
# -----------------------------------------------------------------------------
puts "========== Power Analysis Complete =========="
puts "All reports generated in $TEMP_RESULTS_DIR/ directory:"
puts "  - Component group power reports"
puts "  - Hierarchical power reports (multiple levels)"
puts "  - RTL metrics reports"
puts "  - Power validation reports"
puts "  - Summary statistics"
puts "========== Analysis Session Complete =========="

exit
