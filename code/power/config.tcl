#!/bin/tcsh -f
# =============================================================================
# Shared Configuration File for 45nm CMOS Synthesis Scripts
# =============================================================================
# Description: Common variables and settings for rtla.tcl, restore_new.tcl, 
#              and tz_setup.tcl scripts for blackbox design
# Author: Neuromorphic Accelerator Team
# Technology: 45nm CMOS Process
# =============================================================================

puts "Loading shared configuration..."

# -----------------------------------------------------------------------------
# System Configuration
# -----------------------------------------------------------------------------
# Cores for parallel processing
set CORES 8

# -----------------------------------------------------------------------------
# Design Configuration
# -----------------------------------------------------------------------------
# Design names and top module
set DESIGN_NAME "neuron_accelerator"
set TOP_MODULE  "neuron_accelerator"

# -----------------------------------------------------------------------------
# Library Configuration
# -----------------------------------------------------------------------------
# Library names and references
set LIB_NAME   "LIB"
set REF_LIBS   "NangateOpenCellLibrary"
set TECH_TF    "/tech/45nm/cltrls/saed32nm_1p9m_mw.tf"

# Path configurations
set LIBS_PATH   "/tech/45nm/libs"
set CLTRLS_PATH "/tech/45nm/cltrls"
set RTL_BLACKBOX_PATH "../../../../rtl/neuron_accelerator"

# Search paths for libraries and source files
set SEARCH_PATHS "* ./ ${LIBS_PATH}/NangateOpenCellLibrary.ndm"

# -----------------------------------------------------------------------------
# File Locations
# -----------------------------------------------------------------------------
# Source files
set FILELIST "src.f"

# Power analysis inputs
set FSDB_FILE  "../../../../rtl/neuron_accelerator/novas.fsdb"
set STRIP_PATH "neuron_accelerator_tb/uut"

# -----------------------------------------------------------------------------
# Technology Setup Configuration
# -----------------------------------------------------------------------------
# Parasitic technology files
set TLU_CMAX    "${CLTRLS_PATH}/saed32nm_1p9m_Cmax.tluplus"
set TLU_CMIN    "${CLTRLS_PATH}/saed32nm_1p9m_Cmin.tluplus"
set LAYER_MAP   "${CLTRLS_PATH}/saed32nm_tf_itf_tluplus.map"
set TLU_CMAX_NAME "Cmax"
set TLU_CMIN_NAME "Cmin"

# Clock gating preferences
set CG_MAX_FANOUT 8
set CG_MAX_LEVELS 2
set CG_TARGET     { pos_edge_flip_flop }
set CG_TEST_POINT before
set CG_MIN_BITWIDTH 1

# Scenario configuration
set MODE_NAME     "func"
set CORNER_CMAX   "Cmax"
set CORNER_CMIN   "Cmin"
set SCENARIO_NAME "func@cworst"

# Constraints
set SDC_FILE "./sdc/clocks.sdc"

# -----------------------------------------------------------------------------
# Output Configuration
# -----------------------------------------------------------------------------
# Directory configuration
set RESULT_DIR   "results"
set OUTPUT_DIR   "RTLA_WORKSPACE"

# Temporary results directory for run-time outputs (can be overridden via ENV)
set TEMP_RESULTS_DIR $RESULT_DIR
if {[info exists ::env(TEMP_RESULTS_DIR)]} {
    set TEMP_RESULTS_DIR $::env(TEMP_RESULTS_DIR)
    puts "Using environment TEMP_RESULTS_DIR: $TEMP_RESULTS_DIR"
} else {
    puts "Using default TEMP_RESULTS_DIR: $TEMP_RESULTS_DIR"
}

# -----------------------------------------------------------------------------
# Analysis Configuration
# -----------------------------------------------------------------------------
# Hierarchical levels for reporting
set HIERARCHY_LEVELS {2 3 5 10 20 100}

puts "Configuration loaded successfully"
puts "  Design: $DESIGN_NAME"
puts "  Technology: 45nm CMOS" 
puts "  Cores: $CORES"
puts "  Results directory: $TEMP_RESULTS_DIR"