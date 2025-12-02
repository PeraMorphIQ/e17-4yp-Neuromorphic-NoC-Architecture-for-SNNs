#!/bin/tcsh -f
# =============================================================================
# Alternative Power Analysis Script for SKY130 - Workaround for compute_metrics crash
# =============================================================================
# Description: This script uses an alternative approach to power analysis that
#              avoids the compute_metrics bug causing segmentation faults
# Author: Neuromorphic Accelerator Team  
# Technology: SKY130 130nm Process
# Note: This script DOES NOT use compute_metrics to avoid tool crashes
# =============================================================================

# Load shared configuration
source config.tcl

# -----------------------------------------------------------------------------
# Power Analysis Configuration
# -----------------------------------------------------------------------------
puts "========== Starting Alternative Power Analysis (No compute_metrics) =========="
puts "Technology: SKY130 130nm"
puts "Design: Mesh Neuromorphic NoC Architecture"
puts "Note: Using alternative flow to avoid compute_metrics crash"

# Aggressive memory optimization settings
set_app_var power_enable_rtl_analysis false              ;# Disable RTL analysis
set_app_var power_enable_analysis true
set_app_var power_enable_multi_rtl_to_gate_mapping false ;# Disable to save memory
set_app_var power_enable_advanced_fsdb_reader false      ;# Disabled to save memory

# Memory optimization settings
set_app_var power_enable_memory_optimization true
set_app_var power_rtl_analysis_memory_limit 40000    ;# Limit to 40GB
set_app_var power_enable_incremental_analysis false  ;# Disable incremental
set_app_var power_analysis_effort low                ;# Use lowest effort

# Clock gating analysis settings (disable to avoid crashes)
set_app_var power_enable_clock_gating_analysis false
set_app_var power_clock_gating_inference false
set_app_var power_clock_gating_propagate_enable false

# Hierarchical analysis for large designs  
set_app_var power_hierarchical_analysis true

# Configure parallel processing (minimal to avoid memory pressure)
set_host_options -max_cores 2  ;# Reduced to 2 cores
puts "Using 2 cores for power analysis (minimal to avoid crashes)"

# Set search paths for SKY130 libraries
set search_path $SEARCH_PATHS

# Disable problematic features
set_app_var power_rtl_report_register_use_cg_logic_clustering false

# -----------------------------------------------------------------------------
# Restore Design Data from Synthesis (Supported in pwr_shell)
# -----------------------------------------------------------------------------
puts "========== Restoring Design from Synthesis Output =========="

# Create temp results directory if it doesn't exist
file mkdir $TEMP_RESULTS_DIR

# Restore design using Netlist (Alternative flow)
if {[catch {
    puts "Restoring design from netlist: $OUTPUT_DIR/${DESIGN_NAME}.v"
    
    # Read the netlist
    read_verilog $OUTPUT_DIR/${DESIGN_NAME}.v
    
    # Set top design
    current_design $DESIGN_NAME
    
    # Link the design
    link
    
} result]} {
    puts "ERROR: Netlist restore failed: $result"
    puts "This script requires a completed synthesis run (rtla.tcl) with netlist generation."
    puts "Output directory attempted: ${OUTPUT_DIR}"
    puts "\nAvailable files in output directory:"
    catch {
        foreach f [glob -nocomplain ${OUTPUT_DIR}/*] { puts "  [file tail $f]" }
    }
    exit 1
}

# Try to read constraints (prefer synthesized SDC)
if {[file exists $OUTPUT_DIR/${DESIGN_NAME}.sdc]} {
    puts "Reading synthesized SDC: $OUTPUT_DIR/${DESIGN_NAME}.sdc"
    if {[catch {read_sdc $OUTPUT_DIR/${DESIGN_NAME}.sdc} result]} {
        puts "WARNING: read_sdc failed: $result"
    }
} elseif {[file exists $SDC_FILE]} {
    if {[catch {read_sdc $SDC_FILE} result]} {
        puts "WARNING: read_sdc failed: $result"
    } else {
        puts "Constraints loaded from: $SDC_FILE"
    }
} else {
    puts "WARNING: No SDC file found"
}

# Load activity: prefer FSDB; otherwise fall back to vectorless defaults
if {[file exists $FSDB_FILE]} {
    puts "Reading FSDB activity: $FSDB_FILE"
    if {[catch {read_fsdb -strip_path $STRIP_PATH $FSDB_FILE} result]} {
        puts "WARNING: read_fsdb failed: $result"
        puts "Falling back to vectorless activity (default rates)"
        catch {set_switching_activity -default_toggle_rate 0.2 -default_static_probability 0.5 [current_design]}
    } else {
        puts "FSDB activity loaded successfully"
    }
} else {
    puts "WARNING: FSDB not found at $FSDB_FILE"
    puts "Using vectorless activity defaults (toggle=0.2, static_prob=0.5)"
    catch {set_switching_activity -default_toggle_rate 0.2 -default_static_probability 0.5 [current_design]}
}

# -----------------------------------------------------------------------------
# Basic Power Analysis WITHOUT compute_metrics
# -----------------------------------------------------------------------------
puts "========== Performing Basic Power Analysis =========="

# Update power using restored design and activity
if {[catch {
    update_power
    puts "Power data updated successfully"
} result]} {
    puts "ERROR: update_power failed: $result"
    puts "Cannot proceed with power analysis"
}

# -----------------------------------------------------------------------------
# Generate Basic Power Reports
# -----------------------------------------------------------------------------
puts "========== Generating Basic Power Reports =========="

# Generate basic power report
if {[catch {
    report_power > "$TEMP_RESULTS_DIR/power_basic.txt"
    puts "Basic power report generated"
} result]} {
    puts "WARNING: Basic power report failed: $result"
}

# Generate power by hierarchy (minimal depth)
if {[catch {
    report_power -hierarchy -levels 2 > "$TEMP_RESULTS_DIR/power_hierarchy_level2.txt"
    puts "Hierarchical power report (level 2) generated"
} result]} {
    puts "WARNING: Hierarchical power report failed: $result"
}

# Generate power by instance
if {[catch {
    report_power -instances > "$TEMP_RESULTS_DIR/power_by_instance.txt"
    puts "Power by instance report generated"
} result]} {
    puts "WARNING: Power by instance report failed: $result"
}

# Generate power by net
if {[catch {
    report_power -nets > "$TEMP_RESULTS_DIR/power_by_net.txt"
    puts "Power by net report generated"
} result]} {
    puts "WARNING: Power by net report failed: $result"
}

# Try component group reports
puts "Generating component group reports..."
foreach group {register sequential combinational} {
    if {[catch {
        report_power -group $group > "$TEMP_RESULTS_DIR/power_${group}.txt"
        puts "  - ${group} power report generated"
    } result]} {
        puts "  WARNING: ${group} power report failed: $result"
    }
}

# -----------------------------------------------------------------------------
# Generate Summary Statistics
# -----------------------------------------------------------------------------
puts "========== Generating Summary Statistics =========="

set summary_file [open "$TEMP_RESULTS_DIR/power_analysis_summary.txt" w]
puts $summary_file "# Alternative Power Analysis Summary"
puts $summary_file "# Mesh Neuromorphic NoC Architecture - SKY130 130nm"
puts $summary_file "# Generated: [clock format [clock seconds]]"
puts $summary_file "# Method: Direct power analysis (compute_metrics bypassed)"
puts $summary_file ""

# Try to get basic power information
if {[catch {
    set total_power [get_attribute [current_design] total_power]
    set dynamic_power [get_attribute [current_design] dynamic_power]  
    set leakage_power [get_attribute [current_design] leakage_power]
    
    if {$total_power != ""} {
        puts $summary_file "Total Power: $total_power W"
        puts "Total Power: $total_power W"
    }
    if {$dynamic_power != ""} {
        puts $summary_file "Dynamic Power: $dynamic_power W"
        puts "Dynamic Power: $dynamic_power W"
    }
    if {$leakage_power != ""} {
        puts $summary_file "Leakage Power: $leakage_power W"
        puts "Leakage Power: $leakage_power W"
    }
} result]} {
    puts $summary_file "WARNING: Could not extract power values: $result"
    puts "WARNING: Power value extraction incomplete"
}

puts $summary_file ""
puts $summary_file "Note: This analysis uses an alternative method that bypasses"
puts $summary_file "compute_metrics to avoid tool crashes. RTL-level metrics are"
puts $summary_file "not available with this method."

close $summary_file

# -----------------------------------------------------------------------------
# Completion Message
# -----------------------------------------------------------------------------
puts "========== Alternative Power Analysis Complete =========="
puts "Reports generated in $TEMP_RESULTS_DIR/ directory:"
puts "  - Basic power reports"
puts "  - Hierarchical power reports (limited depth)"
puts "  - Component group power reports"
puts "  - Summary statistics"
puts ""
puts "NOTE: This analysis used an alternative method to avoid tool crashes."
puts "      RTL metrics and detailed analysis are not available."
puts "      For full analysis, consider:"
puts "      1. Reducing design size"
puts "      2. Using a different technology node (16nm/45nm)"
puts "      3. Contacting Synopsys support about compute_metrics bug"
puts "========== Analysis Session Complete =========="

exit
