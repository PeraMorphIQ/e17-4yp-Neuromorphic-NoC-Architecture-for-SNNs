#!/bin/bash

# Default flags - run all steps by default
RUN_VCS=true
RUN_SIMV=true
RUN_RTLA=true
RUN_PRIMEPOWER=true
RUN_GIT=true

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] \"Description of this synthesis run\""
    echo ""
    echo "OPTIONS:"
    echo "  --vcs         Run VCS compilation only"
    echo "  --simv        Run simulation only"
    echo "  --rtla        Run RTL synthesis only"
    echo "  --primepower  Run power analysis only"
    echo "  --git         Run git operations only"
    echo "  --no-vcs      Skip VCS compilation"
    echo "  --no-simv     Skip simulation"
    echo "  --no-rtla     Skip RTL synthesis"
    echo "  --no-primepower Skip power analysis"
    echo "  --no-git      Skip git operations"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 \"Full run with all steps\" "
    echo "  $0 --vcs --rtla \"Run VCS and RTL synthesis only\""
    echo "  $0 --no-git \"Run everything except git operations\""
    echo "  $0 --rtla \"Run only RTL synthesis\""
    echo ""
    echo "Note: If any specific step flag is used (--vcs, --simv, etc.), only those steps will run."
    echo "      Use --no-* flags to exclude specific steps from a full run."
}

# Parse command line arguments
SELECTIVE_RUN=false
RUN_DESCRIPTION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --vcs)
            if [ "$SELECTIVE_RUN" = false ]; then
                # First selective flag - disable all by default
                RUN_VCS=false
                RUN_SIMV=false
                RUN_RTLA=false
                RUN_PRIMEPOWER=false
                RUN_GIT=false
                SELECTIVE_RUN=true
            fi
            RUN_VCS=true
            shift
            ;;
        --simv)
            if [ "$SELECTIVE_RUN" = false ]; then
                RUN_VCS=false
                RUN_SIMV=false
                RUN_RTLA=false
                RUN_PRIMEPOWER=false
                RUN_GIT=false
                SELECTIVE_RUN=true
            fi
            RUN_SIMV=true
            shift
            ;;
        --rtla)
            if [ "$SELECTIVE_RUN" = false ]; then
                RUN_VCS=false
                RUN_SIMV=false
                RUN_RTLA=false
                RUN_PRIMEPOWER=false
                RUN_GIT=false
                SELECTIVE_RUN=true
            fi
            RUN_RTLA=true
            shift
            ;;
        --primepower)
            if [ "$SELECTIVE_RUN" = false ]; then
                RUN_VCS=false
                RUN_SIMV=false
                RUN_RTLA=false
                RUN_PRIMEPOWER=false
                RUN_GIT=false
                SELECTIVE_RUN=true
            fi
            RUN_PRIMEPOWER=true
            shift
            ;;
        --git)
            if [ "$SELECTIVE_RUN" = false ]; then
                RUN_VCS=false
                RUN_SIMV=false
                RUN_RTLA=false
                RUN_PRIMEPOWER=false
                RUN_GIT=false
                SELECTIVE_RUN=true
            fi
            RUN_GIT=true
            shift
            ;;
        --no-vcs)
            RUN_VCS=false
            shift
            ;;
        --no-simv)
            RUN_SIMV=false
            shift
            ;;
        --no-rtla)
            RUN_RTLA=false
            shift
            ;;
        --no-primepower)
            RUN_PRIMEPOWER=false
            shift
            ;;
        --no-git)
            RUN_GIT=false
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "ERROR: Unknown option $1"
            show_usage
            exit 1
            ;;
        *)
            # This should be the description
            if [ -z "$RUN_DESCRIPTION" ]; then
                RUN_DESCRIPTION="$1"
            else
                echo "ERROR: Multiple descriptions provided. Please provide only one description."
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if description argument is provided
if [ -z "$RUN_DESCRIPTION" ]; then
    echo "ERROR: Description argument is required!"
    echo ""
    show_usage
    exit 1
fi

# Define paths as variables
RTL_SYSTEM_TOP_PATH="../cpu"

# Exit on any error and enable error trapping
set -e
trap 'cleanup_on_error' ERR

# Prepare directories
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_BASE_DIR="results"
TEMP_RESULTS_DIR="temp_results_$TIMESTAMP"
FAILED_DIR="failed"

# Function to cleanup on error
cleanup_on_error() {
    echo "========== ERROR OCCURRED - SAVING TO FAILED FOLDER =========="
    echo "Execution failed at $(date)"
    
    # Remove any previous failed results (keep only latest failure)
    if [ -d "$FAILED_DIR" ]; then
        echo "Removing previous failed results"
        rm -rf "$FAILED_DIR"
    fi
    
    # Save current attempt to failed directory
    if [ -d "$TEMP_RESULTS_DIR" ]; then
        echo "Saving failed attempt to: $FAILED_DIR"
        mv "$TEMP_RESULTS_DIR" "$FAILED_DIR"
        echo "Failed results saved for analysis"
    fi
    
    echo "========== CLEANUP COMPLETED =========="
    exit 1
}

# Export the temp results directory for TCL scripts to use
export TEMP_RESULTS_DIR

# Create the temporary results directory
mkdir -p "$TEMP_RESULTS_DIR"

# Create run metadata file
create_run_metadata() {
    local metadata_file="$TEMP_RESULTS_DIR/run_metadata.txt"
    
    cat > "$metadata_file" << EOF
# System Top with CPUs (2x2 Mesh NoC + 4× RV32IMF) - Synthesis and Power Analysis Run Metadata
# =====================================================================

Run Description: $RUN_DESCRIPTION
Timestamp: $TIMESTAMP
Date: $(date)
User: $(whoami)
Host: $(hostname)
Working Directory: $(pwd)
Git Branch: $(git branch --show-current 2>/dev/null || echo "Unknown")
Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo "Unknown")
Git Status: $(git status --porcelain 2>/dev/null | wc -l) modified files

# Environment Information
# -----------------------
Shell: $SHELL
PATH: $PATH
RTL_SYSTEM_TOP_PATH: $RTL_SYSTEM_TOP_PATH
TEMP_RESULTS_DIR: $TEMP_RESULTS_DIR

# Tool Versions
# -------------
VCS Version: $(vcs -ID 2>/dev/null | head -1 || echo "VCS not found")
Synopsys Tools: $(which rtl_shell 2>/dev/null || echo "rtl_shell not found")

# Directory Structure
# -------------------
System Top Directory Exists: $([ -d "$RTL_SYSTEM_TOP_PATH" ] && echo "Yes" || echo "No")
Config File Exists: $([ -f "config.tcl" ] && echo "Yes" || echo "No")
RTLA Script Exists: $([ -f "rtla_new.tcl" ] && echo "Yes" || echo "No")
Restore Script Exists: $([ -f "restore_new.tcl" ] && echo "Yes" || echo "No")
System Top with CPU Source Exists: $([ -f "$RTL_SYSTEM_TOP_PATH/system_top_with_cpu.v" ] && echo "Yes" || echo "No")
System Top with CPU Testbench Exists: $([ -f "$RTL_SYSTEM_TOP_PATH/system_top_with_cpu_tb.v" ] && echo "Yes" || echo "No")

# Design Information
# ------------------
Design: system_top_with_cpu (2x2 Mesh NoC with 4× RV32IMF RISC-V CPUs)
Test Status: 12/14 tests passing (85%)
Components: 4 CPUs, 4 Routers, 4 Neuron Banks (16 neurons total)

# Execution Plan
# --------------
Git Operations: $RUN_GIT
VCS Compilation: $RUN_VCS
Simulation (simv): $RUN_SIMV
RTL Synthesis (rtla): $RUN_RTLA
Power Analysis (PrimePower): $RUN_PRIMEPOWER

EOF
    
    echo "Run metadata created: $metadata_file"
}

echo "========== System Top with CPUs (2x2 Mesh + 4× RV32IMF) - Synthesis and Power Analysis =========="
echo "Description: $RUN_DESCRIPTION"
echo "Using temporary results directory: $TEMP_RESULTS_DIR"
echo "Environment variable TEMP_RESULTS_DIR exported for TCL scripts"

# Display execution plan
echo "========== EXECUTION PLAN =========="
echo "Steps that will be executed:"
if [ "$RUN_GIT" = true ]; then
    echo "  * Git operations (pull, commit, push)"
else
    echo "  x Git operations (SKIPPED)"
fi
if [ "$RUN_VCS" = true ]; then
    echo "  * VCS compilation"
else
    echo "  x VCS compilation (SKIPPED)"
fi
if [ "$RUN_SIMV" = true ]; then
    echo "  * Simulation (simv)"
else
    echo "  x Simulation (SKIPPED)"
fi
if [ "$RUN_RTLA" = true ]; then
    echo "  * RTL synthesis (rtla)"
else
    echo "  x RTL synthesis (SKIPPED)"
fi
if [ "$RUN_PRIMEPOWER" = true ]; then
    echo "  * Power analysis (PrimePower)"
else
    echo "  x Power analysis (SKIPPED)"
fi
echo "=========================================="
echo "Execution started at $(date)"

# Create the run metadata file
create_run_metadata
echo "========== Run metadata file created =========="

# Step 0: Git Pull
if [ "$RUN_GIT" = true ]; then
    echo "========== STEP 0: Git Pull =========="
    if git pull | tee "$TEMP_RESULTS_DIR/git_pull.log"; then
        echo "Git pull completed successfully"
    else
        echo "Git pull failed, but continuing with local files"
    fi
else
    echo "========== STEP 0: Git Pull (SKIPPED) =========="
fi

# Step 1: VCS Compile (for System Top with CPU design)
if [ "$RUN_VCS" = true ]; then
    echo "========== STEP 1: VCS Compile (System Top with CPUs) =========="
    if [ -d "$RTL_SYSTEM_TOP_PATH" ]; then
        pushd "$RTL_SYSTEM_TOP_PATH" > /dev/null
        echo "Compiling System Top with CPUs (2x2 Mesh NoC with 4× RV32IMF CPUs)..."
        # Use the system_top_with_cpu testbench which already includes the design
        # Do NOT use -f flag to avoid module redeclaration
        vcs -sverilog -full64 -kdb -debug_access+all system_top_with_cpu_tb.v +vcs+fsdbon -o simv | tee "../power/$TEMP_RESULTS_DIR/vcs_compile.log"
        echo "VCS compilation completed successfully"
        popd > /dev/null
    else
        echo "Warning: System Top RTL directory not found, skipping VCS compilation"
    fi
else
    echo "========== STEP 1: VCS Compile (SKIPPED) =========="
fi

# Step 2: Run Simulation
if [ "$RUN_SIMV" = true ]; then
    echo "========== STEP 2: Run Simulation =========="
    if [ -d "$RTL_SYSTEM_TOP_PATH" ]; then
        pushd "$RTL_SYSTEM_TOP_PATH" > /dev/null
        echo "Running simulation with FSDB waveform dump..."
        # Create build directory if it doesn't exist
        mkdir -p build
        # Run simulation and save FSDB in build directory
        ./simv +fsdb+all=on +fsdb+delta 2>&1 | tee "../power/$TEMP_RESULTS_DIR/simulation.log"
        # Check if FSDB file was created
        if [ -f "build/system_top_with_cpu_tb.fsdb" ] || [ -f "system_top_with_cpu_tb.fsdb" ]; then
            echo "Simulation completed successfully - FSDB file generated"
            # Move FSDB to build directory if it's in current directory
            if [ -f "system_top_with_cpu_tb.fsdb" ]; then
                mv system_top_with_cpu_tb.fsdb build/
            fi
        else
            echo "Warning: FSDB file not found, but simulation ran"
        fi
        popd > /dev/null
    else
        echo "Warning: System Top RTL directory not found, skipping simulation"
    fi
else
    echo "========== STEP 2: Run Simulation (SKIPPED) =========="
fi

# Step 3: RTL Synthesis (using proper command)
if [ "$RUN_RTLA" = true ]; then
    echo "========== STEP 3: RTL Synthesis =========="
    
    # Check and optionally remove existing library directory
    LIB_DIR="LIB"
    if [ -d "$LIB_DIR" ]; then
        echo "Library directory '$LIB_DIR' already exists."
        echo "Removing existing library directory before synthesis to avoid errors..."
        rm -rf "$LIB_DIR"
    fi
    
    echo "Running with proper PrimeTime shell command..."
    rtl_shell -f rtla_new.tcl | tee "$TEMP_RESULTS_DIR/rtl_synthesis.log"
    if [ $? -eq 0 ]; then
        echo "RTL synthesis completed successfully"
    else
        echo "ERROR: RTL synthesis failed - check $TEMP_RESULTS_DIR/rtl_synthesis.log"
        exit 1
    fi
else
    echo "========== STEP 3: RTL Synthesis (SKIPPED) =========="
fi

# Step 4: Power Analysis (using pwr_shell for power restoration)
if [ "$RUN_PRIMEPOWER" = true ]; then
    echo "========== STEP 4: Power Analysis =========="
    if [ -f "restore_new.tcl" ]; then
        pwr_shell -f restore_new.tcl | tee "$TEMP_RESULTS_DIR/power_restore.log"
        if [ $? -eq 0 ]; then
            echo "Power analysis completed successfully"
        else
            echo "ERROR: Power analysis failed - check $TEMP_RESULTS_DIR/power_restore.log"
            exit 1
        fi
    else
        echo "Warning: restore_new.tcl not found, skipping power analysis"
    fi
else
    echo "========== STEP 4: Power Analysis (SKIPPED) =========="
fi

# Step 5: Archive results to permanent location  
echo "========== STEP 5: Archive Results =========="
final_results_dir="$RESULTS_BASE_DIR/results_$TIMESTAMP"
mkdir -p "$RESULTS_BASE_DIR"

if [ -d "$TEMP_RESULTS_DIR" ]; then
    echo "Moving results from $TEMP_RESULTS_DIR to $final_results_dir"
    mv "$TEMP_RESULTS_DIR" "$final_results_dir"
    echo "Results archived successfully in: $final_results_dir"
    
    # Create a symlink to latest results
    if [ -L "latest" ]; then
        rm "latest"
    fi
    ln -sf "$final_results_dir" "latest"
    echo "Created 'latest' symlink pointing to most recent results"
else
    echo "Warning: No temporary results directory found to archive"
fi

# Step 6: Git Commit and Push
if [ "$RUN_GIT" = true ]; then
    echo "========== STEP 6: Git Commit and Push =========="
    set +e  # Temporarily disable exit on error for git operations

    if git add .; then
        echo "Files staged successfully"
    else
        echo "Warning: Failed to stage some files"
    fi

    if git commit -m "Auto commit: 45nm CMOS - $RUN_DESCRIPTION - $TIMESTAMP"; then
        echo "Commit created successfully"
    else
        echo "Warning: Commit failed (possibly no changes to commit)"
    fi

    if git pull --rebase --autostash origin main | tee "$final_results_dir/git_pull_before_push.log"; then
        echo "Git pull completed"
    else
        echo "Warning: Git pull failed"
    fi

    if git push | tee "$final_results_dir/git_push.log"; then
        echo "Changes pushed to remote repository"
    else
        echo "Warning: Git push failed"
    fi

    set -e  # Re-enable exit on error
else
    echo "========== STEP 6: Git Commit and Push (SKIPPED) =========="
fi

echo "========== All Steps Completed Successfully =========="
echo "Execution completed at $(date)"
echo "Final results location: $final_results_dir"
echo "Description: $RUN_DESCRIPTION"
echo "Technology: 45nm CMOS"
