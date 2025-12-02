#!/bin/tcsh -f
# =============================================================================
# Power Analysis Script for SKY130 - Using read_power_data
# =============================================================================
# Description: This script uses read_power_data to restore synthesis results
#              and perform power analysis
# Author: Neuromorphic Accelerator Team  
# Technology: SKY130 130nm Process
# =============================================================================

# Load shared configuration
source config.tcl

# -----------------------------------------------------------------------------
# Power Analysis Configuration
# -----------------------------------------------------------------------------
puts "========== Starting Power Analysis =========="
puts "Technology: SKY130 130nm"
puts "Design: Mesh Neuromorphic NoC Architecture"

# Basic settings - only use valid pwr_shell app_vars
set_app_var power_enable_analysis true

# Configure parallel processing
set_host_options -max_cores $CORES
puts "Using $CORES cores for power analysis"

# Set search paths for SKY130 libraries
set search_path $SEARCH_PATHS

# -----------------------------------------------------------------------------
# Restore Design Data from Synthesis
# -----------------------------------------------------------------------------
puts "========== Restoring Design from RTL Synthesis Output =========="

# Create temp results directory if it doesn't exist
file mkdir $TEMP_RESULTS_DIR

# Check what files are available in OUTPUT_DIR
puts "Checking available files in $OUTPUT_DIR..."
if {[file exists $OUTPUT_DIR]} {
    foreach f [glob -nocomplain ${OUTPUT_DIR}/*] { 
        puts "  Found: [file tail $f]" 
    }
} else {
    puts "ERROR: Output directory $OUTPUT_DIR does not exist!"
    puts "Please run rtla.tcl first to generate synthesis data."
    exit 1
}

# Try to restore using read_power_data with the .pp file
set pp_file "${OUTPUT_DIR}/run_${SCENARIO_NAME}.pp"
set pp_file_alt "${OUTPUT_DIR}/run.pp"

if {[file exists $pp_file]} {
    puts "Restoring power data from: $pp_file"
    if {[catch {read_power_data $pp_file} result]} {
        puts "ERROR: read_power_data failed: $result"
        puts "Trying alternative .pp file..."
        if {[file exists $pp_file_alt]} {
            if {[catch {read_power_data $pp_file_alt} result2]} {
                puts "ERROR: Alternative read_power_data also failed: $result2"
                exit 1
            }
        } else {
            exit 1
        }
    }
} elseif {[file exists $pp_file_alt]} {
    puts "Restoring power data from: $pp_file_alt"
    if {[catch {read_power_data $pp_file_alt} result]} {
        puts "ERROR: read_power_data failed: $result"
        exit 1
    }
} else {
    puts "ERROR: No .pp file found in $OUTPUT_DIR"
    puts "Expected: $pp_file or $pp_file_alt"
    exit 1
}

puts "Power data restored successfully"

# -----------------------------------------------------------------------------
# Load Switching Activity from FSDB
# -----------------------------------------------------------------------------
puts "========== Loading Switching Activity =========="

if {[file exists $FSDB_FILE]} {
    puts "Reading FSDB activity: $FSDB_FILE"
    puts "Strip path: $STRIP_PATH"
    if {[catch {read_fsdb -strip_path $STRIP_PATH $FSDB_FILE} result]} {
        puts "WARNING: read_fsdb failed: $result"
        puts "Continuing with default switching activity..."
    } else {
        puts "FSDB activity loaded successfully"
    }
} else {
    puts "WARNING: FSDB file not found at $FSDB_FILE"
    puts "Continuing with default switching activity..."
}

# -----------------------------------------------------------------------------
# Update and Analyze Power
# -----------------------------------------------------------------------------
puts "========== Performing Power Analysis =========="

# Update power calculations
if {[catch {update_power} result]} {
    puts "WARNING: update_power failed: $result"
    puts "Continuing to generate reports..."
}

# -----------------------------------------------------------------------------
# Generate Power Reports
# -----------------------------------------------------------------------------
puts "========== Generating Power Reports =========="

# Generate basic power report
puts "Generating basic power report..."
if {[catch {report_power > "$TEMP_RESULTS_DIR/power_basic.txt"} result]} {
    puts "WARNING: Basic power report failed: $result"
} else {
    puts "  - power_basic.txt generated"
}

# Generate detailed power report
puts "Generating detailed power report..."
if {[catch {report_power -verbose > "$TEMP_RESULTS_DIR/power_detailed.txt"} result]} {
    puts "WARNING: Detailed power report failed: $result"
} else {
    puts "  - power_detailed.txt generated"
}

# Generate hierarchical power reports
puts "Generating hierarchical power reports..."
foreach level {2 3 5} {
    if {[catch {report_power -hierarchy -levels $level > "$TEMP_RESULTS_DIR/power_hierarchy_L${level}.txt"} result]} {
        puts "WARNING: Hierarchical power report (level $level) failed: $result"
    } else {
        puts "  - power_hierarchy_L${level}.txt generated"
    }
}

# Generate power by cell type
puts "Generating power by cell type..."
if {[catch {report_power -cell_type > "$TEMP_RESULTS_DIR/power_by_cell_type.txt"} result]} {
    puts "WARNING: Power by cell type report failed: $result"
} else {
    puts "  - power_by_cell_type.txt generated"
}

# Generate power by group
puts "Generating power by component groups..."
foreach group {register sequential combinational memory clock_network} {
    if {[catch {report_power -groups $group > "$TEMP_RESULTS_DIR/power_${group}.txt"} result]} {
        # Try alternative syntax
        if {[catch {report_power -group $group > "$TEMP_RESULTS_DIR/power_${group}.txt"} result2]} {
            puts "  WARNING: $group power report failed"
        } else {
            puts "  - power_${group}.txt generated"
        }
    } else {
        puts "  - power_${group}.txt generated"
    }
}

# -----------------------------------------------------------------------------
# Extract and Display Power Summary
# -----------------------------------------------------------------------------
puts "========== Power Analysis Summary =========="

# Create summary file
set summary_file [open "$TEMP_RESULTS_DIR/power_summary.txt" w]
puts $summary_file "=============================================="
puts $summary_file "Power Analysis Summary"
puts $summary_file "=============================================="
puts $summary_file "Design: $DESIGN_NAME"
puts $summary_file "Technology: SKY130 130nm"
puts $summary_file "Generated: [clock format [clock seconds]]"
puts $summary_file "=============================================="
puts $summary_file ""

# Try to extract power values
if {[catch {
    # Get the current design
    set design [current_design]
    puts $summary_file "Design: $design"
    puts "Design: $design"
    
    # Try different methods to get power
    if {[catch {set total [get_attribute $design total_power]} err]} {
        puts "Could not get total_power attribute: $err"
    } else {
        puts $summary_file "Total Power: $total W"
        puts "Total Power: $total W"
    }
    
    if {[catch {set dynamic [get_attribute $design dynamic_power]} err]} {
        puts "Could not get dynamic_power attribute"  
    } else {
        puts $summary_file "Dynamic Power: $dynamic W"
        puts "Dynamic Power: $dynamic W"
    }
    
    if {[catch {set leakage [get_attribute $design leakage_power]} err]} {
        puts "Could not get leakage_power attribute"
    } else {
        puts $summary_file "Leakage Power: $leakage W"
        puts "Leakage Power: $leakage W"
    }
    
} result]} {
    puts $summary_file "Note: Could not extract all power attributes"
    puts "Note: Power extraction incomplete - check report files"
}

puts $summary_file ""
puts $summary_file "Detailed reports available in: $TEMP_RESULTS_DIR/"
close $summary_file

# Also print the basic power report to console
puts ""
puts "=============================================="
puts "Basic Power Report:"
puts "=============================================="
if {[catch {report_power} result]} {
    puts "Could not generate console power report"
}

# -----------------------------------------------------------------------------
# Completion Message
# -----------------------------------------------------------------------------
puts ""
puts "========== Power Analysis Complete =========="
puts "Reports generated in $TEMP_RESULTS_DIR/:"
puts "  - power_basic.txt"
puts "  - power_detailed.txt"  
puts "  - power_hierarchy_L*.txt"
puts "  - power_by_cell_type.txt"
puts "  - power_summary.txt"
puts "========== Done =========="

exit
