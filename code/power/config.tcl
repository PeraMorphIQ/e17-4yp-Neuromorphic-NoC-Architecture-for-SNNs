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
# Options: "system_top" (NoC with neuron banks - WORKING) or "system_top_with_cpu" (with CPUs - 12/14 tests passing)
set DESIGN_NAME "system_top_with_cpu"
set TOP_MODULE  "system_top_with_cpu"

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
set RTL_SYSTEM_TOP_PATH "../cpu"

# Search paths for libraries and source files
set SEARCH_PATHS "* ./ ${LIBS_PATH}/NangateOpenCellLibrary.ndm"

# -----------------------------------------------------------------------------
# File Locations
# -----------------------------------------------------------------------------
# Source files (choose appropriate file list)
# set FILELIST "system_top_src.f"                  # NoC with neuron banks (WORKING - ALL TESTS PASS)

# Complete design with RV32IMF CPUs (12/14 tests passing - 85%)
set FILELIST "system_top_with_cpu_src.f"

# Power analysis inputs
set FSDB_FILE  "../cpu/novas.fsdb"
set STRIP_PATH "system_top_with_cpu_tb/dut"

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
set SDC_FILE "./sdc/clocks_with_cpu.sdc"

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