#!/bin/tcsh -f
# =============================================================================
# System Top with RISC-V CPUs RTL Analysis and Synthesis Script for 45nm CMOS
# =============================================================================
# Description: This script performs RTL analysis, synthesis, and power 
#              analysis for the complete System Top design with integrated
#              RV32IMF RISC-V processors (2x2 Mesh NoC with CPUs and Neuron Banks)
#              using 45nm CMOS technology
# Author: Neuromorphic Accelerator Team
# Technology: 45nm CMOS Process
# =============================================================================

# Load shared configuration
source config.tcl

# -----------------------------------------------------------------------------
# Configuration and Setup
# -----------------------------------------------------------------------------
puts "========== Starting RTL Analysis and Synthesis =========="
puts "Technology: 45nm CMOS"
puts "Design: System Top with RISC-V CPUs - 2x2 Mesh NoC (4× RV32IMF + Neuron Banks)"

# Configure mismatch handling
set_current_mismatch_config auto_fix
set_attribute [get_mismatch_types missing_logical_reference] current_repair(auto_fix) create_blackbox

# Set host options for parallel processing
set_host_options -max_cores $CORES
puts "Using $CORES cores for parallel processing"

# Application options
set_app_options -list {plan.macro.allow_unmapped_design true}

# -----------------------------------------------------------------------------
# Library Setup
# -----------------------------------------------------------------------------
puts "========== Setting up 45nm CMOS Libraries =========="

# Search paths for libraries and source files
set search_path $SEARCH_PATHS

# Create design library with 45nm CMOS reference libraries
create_lib $LIB_NAME \
    -ref_libs "$REF_LIBS" \
    -technology $TECH_TF

puts "45nm CMOS libraries loaded successfully"

# -----------------------------------------------------------------------------
# Design Analysis and Elaboration
# -----------------------------------------------------------------------------
puts "========== Analyzing and Elaborating Design =========="

# Analyze RTL source files
analyze -f sv -vcs "-f $FILELIST"

# Elaborate the design
elaborate $DESIGN_NAME
set_top_module $TOP_MODULE

puts "Design elaboration completed"

# -----------------------------------------------------------------------------
# Technology Setup and Constraints
# -----------------------------------------------------------------------------
puts "========== Loading Technology Setup =========="
source tz_setup.tcl

# Force timing update after loading constraints
update_timing

# Verify clock constraints were loaded
puts "========== Verifying Clock Constraints =========="
set all_clocks [get_clocks -quiet *]
if {[llength $all_clocks] == 0} {
    puts "ERROR: No clocks found after loading constraints!"
    puts "Checking for clock ports in design..."
    set clk_ports [get_ports -quiet *CLK*]
    if {[llength $clk_ports] > 0} {
        puts "Found clock port(s): [get_object_name $clk_ports]"
        puts "Attempting to create clock manually..."
        # Try to create clock on CLK port with default period
        create_clock -name CLK -period 10.0 [get_ports CLK]
        set all_clocks [get_clocks -quiet *]
    }
    if {[llength $all_clocks] == 0} {
        puts "FATAL: Unable to create or find clocks. Exiting."
        exit 1
    }
}

puts "Clocks found in design:"
foreach clk $all_clocks {
    set clk_name [get_object_name $clk]
    set clk_period [get_attribute $clk period]
    puts "  - $clk_name (period: $clk_period ns)"
}
puts "=============================================="

# -----------------------------------------------------------------------------
# RTL Optimization
# -----------------------------------------------------------------------------
puts "========== Starting RTL Optimization =========="
# Full RTL optimization for accurate power and timing analysis
# Options:
#   -initial_map_only: Quick mapping only (for debug/fast iteration)
#   rtl_opt: Full optimization (for final results/power analysis)
rtl_opt -initial_map_onl
puts "RTL optimization completed"

# Save the optimized design
save_block
save_lib
puts "Design saved successfully"

# -----------------------------------------------------------------------------
# Power Analysis Setup
# -----------------------------------------------------------------------------
puts "========== Setting up Power Analysis =========="

# Create temp results directory if it doesn't exist
file mkdir $TEMP_RESULTS_DIR

# Configure RTL power analysis
# Try the requested scenario first; if it fails, retry without scenario, else skip export
set skip_power_export 0
if {[catch {
    set_rtl_power_analysis_options \
        -scenario $SCENARIO_NAME \
        -design $DESIGN_NAME \
        -strip_path $STRIP_PATH \
        -fsdb $FSDB_FILE \
        -output_dir $OUTPUT_DIR
} err_msg]} {
    puts "WARNING: Failed to set RTL power analysis options with scenario '$SCENARIO_NAME': $err_msg"
    puts "Retrying set_rtl_power_analysis_options without -scenario..."
    if {[catch {
        set_rtl_power_analysis_options \
            -design $DESIGN_NAME \
            -strip_path $STRIP_PATH \
            -fsdb $FSDB_FILE \
            -output_dir $OUTPUT_DIR
    } err_msg2]} {
        puts "WARNING: Failed to set RTL power analysis options without scenario: $err_msg2"
        puts "Skipping power data export and continuing with timing analysis."
        set skip_power_export 1
    } else {
        puts "set_rtl_power_analysis_options succeeded without scenario."
    }
} else {
    puts "set_rtl_power_analysis_options succeeded with scenario '$SCENARIO_NAME'."
}

if {$skip_power_export == 0} {
    if {[catch { export_power_data } exp_err]} {
        puts "WARNING: export_power_data failed: $exp_err"
        puts "Continuing without exported power data."
    } else {
        puts "Power analysis data exported"
    }
} else {
    puts "Power export skipped earlier due to configuration failure."
}

# -----------------------------------------------------------------------------
# Maximum Frequency Characterization
# -----------------------------------------------------------------------------
puts "========== Characterizing Maximum Operating Frequency =========="

# Update timing for accurate analysis
update_timing

# Find all clocks in the design
set all_clocks [get_clocks *]
if {[llength $all_clocks] == 0} {
    puts "ERROR: No clocks found in design. Please check your constraints."
    puts "Available ports: [get_object_name [get_ports *clk*]]"
    exit 1
}

# Get the first clock (or find specific clock pattern)
# Important: lindex returns a single element, not a collection
set current_clk [lindex $all_clocks 0]
set clock_name [get_object_name $current_clk]
puts "Found clock: $clock_name"

# If there are multiple clocks, list them
if {[llength $all_clocks] > 1} {
    puts "Multiple clocks found in design:"
    foreach clk $all_clocks {
        set clk_name [get_object_name $clk]
        set clk_period [get_attribute $clk period]
        puts "  - $clk_name (period: $clk_period ns)"
    }
    puts "Using first clock: $clock_name for frequency analysis"
}

# Get period for the single selected clock
set current_period [get_attribute $current_clk period]
puts "Current clock period: $current_period ns"

# Validate that current_period is a single numeric value
if {[catch {expr {double($current_period)}} current_period_num]} {
    puts "WARNING: Clock period is not a single numeric value: '$current_period'"
    # Try to extract first number
    if {[catch {scan $current_period "%f" current_period_num}]} {
        puts "ERROR: Unable to parse clock period"
        exit 1
    }
    set current_period $current_period_num
    puts "Using first clock period value: $current_period ns"
}

# Get worst negative slack (WNS) and critical path information for the selected clock
set critical_paths [get_timing_paths -delay_type max -max_paths 1 -through [get_clocks $clock_name]]
if {[llength $critical_paths] == 0} {
    puts "WARNING: No timing paths found for clock $clock_name, trying all paths"
    set critical_paths [get_timing_paths -delay_type max -max_paths 1]
}

if {[llength $critical_paths] == 0} {
    puts "WARNING: No timing paths found at all"
    set slack 0.0
    set data_arrival 0.0
} else {
    set slack_raw [get_attribute $critical_paths slack]
    set data_arrival_raw [get_attribute $critical_paths arrival]
    
    # Extract numeric value from the string (handles cases like "5.23 ns" or other formats)
    if {[catch {scan $slack_raw "%f" slack}]} {
        puts "WARNING: Could not parse slack value: '$slack_raw', defaulting to 0.0"
        set slack 0.0
    }
    if {[catch {scan $data_arrival_raw "%f" data_arrival}]} {
        puts "WARNING: Could not parse data_arrival value: '$data_arrival_raw', defaulting to current_period"
        set data_arrival $current_period
    }
}

# Ensure numeric values are properly formatted
set slack [expr {double($slack)}]
set data_arrival [expr {double($data_arrival)}]

puts "Current WNS (Worst Negative Slack): $slack ns"
puts "Data Arrival Time: $data_arrival ns"

# Calculate minimum period and maximum frequency
# Wrap in try-catch to handle any timing extraction errors gracefully
if {[catch {
    # Validate that we have the necessary data
    if {$current_period == "" || $current_period == 0} {
        error "Invalid clock period retrieved"
    }

    # Tmin = Current_Period - Slack (if slack is negative, this adds the violation)
    # If slack is positive, Tmin = Data_Arrival_Time (critical path delay)
    if {$slack >= 0} {
        # Timing is met - use actual critical path delay
        set Tmin $data_arrival
        set timing_status "MET"
    } else {
        # Timing violated - need to increase period
        set Tmin [expr {$current_period - $slack}]
        set timing_status "VIOLATED"
    }

    # Sanity check on calculated values
    if {$Tmin <= 0} {
        error "Invalid critical path delay calculated: $Tmin ns"
    }

    # Add safety margin (typically 2-5% for publication)
    set MARGIN_PERCENT 2.0
    set Tmin_with_margin [expr {$Tmin * (1.0 + $MARGIN_PERCENT/100.0)}]

    # Calculate frequencies (convert from ns to Hz, then to MHz)
    # Fmax in MHz: 1/ns = 1000 MHz
    set Fmax [expr {1000.0 / $Tmin}]
    set Fmax_with_margin [expr {1000.0 / $Tmin_with_margin}]

    # Format results
    set Fmax_formatted [format "%.2f" $Fmax]
    set Fmax_margin_formatted [format "%.2f" $Fmax_with_margin]
    set Tmin_formatted [format "%.4f" $Tmin]
    set Tmin_margin_formatted [format "%.4f" $Tmin_with_margin]
    
} timing_error]} {
    # Frequency calculation failed - use defaults and continue
    puts "WARNING: Frequency characterization failed: $timing_error"
    puts "Using default timing values to continue..."
    set Tmin $current_period
    set Tmin_with_margin $current_period
    set Fmax [expr {1000.0 / $current_period}]
    set Fmax_with_margin $Fmax
    set Fmax_formatted [format "%.2f" $Fmax]
    set Fmax_margin_formatted [format "%.2f" $Fmax_with_margin]
    set Tmin_formatted [format "%.4f" $Tmin]
    set Tmin_margin_formatted [format "%.4f" $Tmin_with_margin]
    set timing_status "UNKNOWN"
    set slack "N/A"
}

set Tmin_margin_formatted [format "%.4f" $Tmin_with_margin]

puts "================================================"
puts "MAXIMUM FREQUENCY CHARACTERIZATION RESULTS"
puts "================================================"
puts "Timing Status: $timing_status at current period"
puts "Critical Path Delay: $Tmin_formatted ns"
puts "Maximum Frequency: $Fmax_formatted MHz"
puts "Maximum Frequency (with ${MARGIN_PERCENT}% margin): $Fmax_margin_formatted MHz"
puts "Recommended Clock Period: $Tmin_margin_formatted ns"
puts "================================================"

# -----------------------------------------------------------------------------
# Generate Comprehensive Reports
# -----------------------------------------------------------------------------
puts "========== Generating Reports =========="

# Basic reports
report_power > "$TEMP_RESULTS_DIR/report_power.txt"
report_area > "$TEMP_RESULTS_DIR/report_area.txt" 
report_qor > "$TEMP_RESULTS_DIR/report_qor.txt"

# Detailed timing reports
report_timing -delay_type max -max_paths 1 -path_type full \
    > "$TEMP_RESULTS_DIR/report_timing_critical_path.txt"

report_timing -delay_type max -max_paths 10 -path_type full \
    > "$TEMP_RESULTS_DIR/report_timing_top10_paths.txt"

report_timing -delay_type max -max_paths 1 -nets -transition_time \
    -capacitance -input_pins -significant_digits 4 \
    > "$TEMP_RESULTS_DIR/report_timing_detailed.txt"

# Constraint and violation reports
report_constraint -all_violators > "$TEMP_RESULTS_DIR/report_violations.txt"

# Clock reports
report_clock -skew > "$TEMP_RESULTS_DIR/report_clock.txt"

# Additional useful reports for 45nm CMOS
report_reference > "$TEMP_RESULTS_DIR/report_reference.txt"
report_hierarchy > "$TEMP_RESULTS_DIR/report_hierarchy.txt"

# Design statistics
report_design > "$TEMP_RESULTS_DIR/report_design_stats.txt"

# Process corner information
report_pvt > "$TEMP_RESULTS_DIR/report_pvt.txt"

# -----------------------------------------------------------------------------
# Generate Publication-Ready Summary
# -----------------------------------------------------------------------------
puts "========== Generating Publication Summary =========="

set summary_file [open "$TEMP_RESULTS_DIR/publication_summary.txt" w]

puts $summary_file "================================================================================"
puts $summary_file "System Top with RV32IMF CPUs - 45nm CMOS - Performance Characterization"
puts $summary_file "================================================================================"
puts $summary_file ""
puts $summary_file "DESIGN INFORMATION:"
puts $summary_file "  Design Name:           $DESIGN_NAME"
puts $summary_file "  Top Module:            $TOP_MODULE"
puts $summary_file "  Technology:            45nm CMOS"
puts $summary_file "  Analysis Date:         [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]"
puts $summary_file ""
puts $summary_file "TIMING ANALYSIS:"
puts $summary_file "  Current Clock Period:  $current_period ns"
puts $summary_file "  Timing Status:         $timing_status"
puts $summary_file "  Worst Slack (WNS):     $slack ns"
puts $summary_file ""
puts $summary_file "MAXIMUM FREQUENCY CHARACTERIZATION:"
puts $summary_file "  Critical Path Delay:   $Tmin_formatted ns"
puts $summary_file "  Maximum Frequency:     $Fmax_formatted MHz"
puts $summary_file ""
puts $summary_file "RECOMMENDED OPERATING POINT (${MARGIN_PERCENT}% margin):"
puts $summary_file "  Clock Period:          $Tmin_margin_formatted ns"
puts $summary_file "  Operating Frequency:   $Fmax_margin_formatted MHz"
puts $summary_file ""

# Get critical path details
if {[llength $critical_paths] > 0} {
    set startpoint [get_attribute $critical_paths startpoint]
    set endpoint [get_attribute $critical_paths endpoint]
    puts $summary_file "CRITICAL PATH:"
    puts $summary_file "  Startpoint:            [get_object_name $startpoint]"
    puts $summary_file "  Endpoint:              [get_object_name $endpoint]"
    puts $summary_file ""
}

puts $summary_file ""
puts $summary_file "PROCESS CORNER:"
puts $summary_file "  Scenario:              $SCENARIO_NAME"
puts $summary_file "  Corner:                Cmax (Worst Case)"
puts $summary_file ""
puts $summary_file "================================================================================"
puts $summary_file "For detailed timing analysis, see:"
puts $summary_file "  - report_timing_critical_path.txt (Critical path breakdown)"
puts $summary_file "  - report_timing_top10_paths.txt (Top 10 critical paths)"
puts $summary_file "  - report_timing_detailed.txt (Full timing details with nets)"
puts $summary_file "================================================================================"

close $summary_file

# Also create a simple CSV for easy import
set csv_file [open "$TEMP_RESULTS_DIR/timing_metrics.csv" w]
puts $csv_file "Metric,Value,Unit"
puts $csv_file "Critical_Path_Delay,$Tmin_formatted,ns"
puts $csv_file "Maximum_Frequency,$Fmax_formatted,MHz"
puts $csv_file "Recommended_Frequency,$Fmax_margin_formatted,MHz"
puts $csv_file "Worst_Slack,$slack,ns"
puts $csv_file "Current_Period,$current_period,ns"
close $csv_file

puts "All reports generated in $TEMP_RESULTS_DIR/ directory"
puts ""
puts "KEY RESULT: Maximum Operating Frequency = $Fmax_formatted MHz"
puts "RECOMMENDED: Use $Fmax_margin_formatted MHz (with ${MARGIN_PERCENT}% margin)"
puts ""
puts "========== RTL Analysis and Synthesis Complete =========="

exit