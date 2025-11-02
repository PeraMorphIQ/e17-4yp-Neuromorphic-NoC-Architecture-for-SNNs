#!/bin/tcsh -f
# =============================================================================
# Technology Setup Script for 45nm CMOS Process
# =============================================================================
# Description: Technology-specific setup for synthesis and optimization
#              targeting 45nm CMOS process technology for System Top
#              (2x2 Mesh NoC with Neuron Banks)
# Author: Neuromorphic Accelerator Team
# Technology: 45nm CMOS Process
# =============================================================================

# Load shared configuration
source config.tcl

puts "========== 45nm CMOS Technology Setup =========="

# -----------------------------------------------------------------------------
# Synthesis Flow Options
# -----------------------------------------------------------------------------
puts "Configuring synthesis flow options..."

# Enable multi-bit register inference for better area and power
set_app_options -list {compile.flow.enable_multibit true}

# Disable TCL error returns for compatibility
set_app_options -name shell.dc_compatibility.return_tcl_errors -value false

# Control ungrouping behavior
set_app_options -name compile.flow.autoungroup -value false

# Clock gating minimum bitwidth setting
set_clock_gating_options -minimum_bitwidth $CG_MIN_BITWIDTH

# -----------------------------------------------------------------------------
# Parasitic Technology Files for 45nm CMOS
# -----------------------------------------------------------------------------
puts "Loading 45nm CMOS parasitic technology files..."

# Load parasitic extraction data for 45nm CMOS corners
read_parasitic_tech \
    -tlup $TLU_CMAX \
    -layermap $LAYER_MAP \
    -name $TLU_CMAX_NAME

read_parasitic_tech \
    -tlup $TLU_CMIN \
    -layermap $LAYER_MAP \
    -name $TLU_CMIN_NAME

puts "45nm CMOS parasitic models loaded"

# -----------------------------------------------------------------------------
# Clock Gating Configuration for 45nm CMOS
# -----------------------------------------------------------------------------
puts "Setting up clock gating options for 45nm CMOS..."

# Map SELECT operations to MUX for better optimization
set_attribute -objects [get_cells -hier -filter "ref_name=~*SELECT_OP*"] -name map_to_mux -value true

# Disable datapath ungrouping for DesignWare components
set_app_options -name compile.datapath.ungroup -value false
set_app_options -as_user_default -list {ungr.dw.hlo_enable_dw_ungrp false}

# Clock gating options optimized for 45nm CMOS process
set_clock_gating_options \
    -max_fanout $CG_MAX_FANOUT \
    -max_number_of_levels $CG_MAX_LEVELS

# Configure clock gate style for 45nm CMOS
set_clock_gate_style -target $CG_TARGET -test_point $CG_TEST_POINT

puts "Clock gating configured for 45nm CMOS"

# -----------------------------------------------------------------------------
# Optimization Control
# -----------------------------------------------------------------------------
puts "Setting optimization controls..."

# Disable boundary optimization for better control
set_app_option -name rtl_opt.conditioning.disable_boundary_optimization_and_auto_ungrouping -value true

# Set user defaults for optimization control
set_app_options -as_user_default -list {compile.flow.autoungroup false}
set_app_options -as_user_default -list {compile.flow.boundary_optimization false}

# -----------------------------------------------------------------------------
# Operating Scenarios Setup
# -----------------------------------------------------------------------------
puts "Creating operating scenarios..."

# Create functional mode
create_mode $MODE_NAME

# Create corners for 45nm CMOS (max and min case)
create_corner $CORNER_CMAX
create_corner $CORNER_CMIN

# Create scenarios combining mode and corners
create_scenario -mode $MODE_NAME -corner $CORNER_CMAX -name func@Cmax
create_scenario -mode $MODE_NAME -corner $CORNER_CMIN -name func@Cmin

# Set parasitic parameters for both scenarios
set_parasitic_parameters \
    -corner $CORNER_CMIN \
    -late_spec $TLU_CMIN_NAME \
    -early_spec $TLU_CMIN_NAME

set_parasitic_parameters \
    -corner $CORNER_CMAX \
    -late_spec $TLU_CMAX_NAME \
    -early_spec $TLU_CMAX_NAME

# Disable hold time analysis for both scenarios
set_scenario_status [list func@Cmax func@Cmin] -hold false

# Set current scenario to minimum corner
current_scenario func@Cmin

puts "Operating scenarios created and set"

# -----------------------------------------------------------------------------
# Load Design Constraints
# -----------------------------------------------------------------------------
puts "Loading design constraints..."

# Source clock constraints
if {[file exists $SDC_FILE]} {
    source $SDC_FILE
    puts "Clock constraints loaded from $SDC_FILE"
} else {
    puts "Warning: Clock constraints file $SDC_FILE not found"
}

# -----------------------------------------------------------------------------
# Report Setup Status
# -----------------------------------------------------------------------------
puts "========== Setup Status Report =========="
report_scenarios
puts "========== 45nm CMOS Technology Setup Complete =========="
