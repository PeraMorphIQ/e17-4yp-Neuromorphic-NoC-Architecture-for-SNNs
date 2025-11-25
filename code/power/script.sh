#!/bin/bash

# Default flags - run all steps by default
RUN_VCS=true
RUN_SIMV=true
RUN_RTLA=true
RUN_PRIMEPOWER=true
RUN_GIT=true
USE_RESTORE=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] \"Description of this synthesis run\""
    echo ""
    echo "OPTIONS:"
    echo "  --vcs         Run VCS compilation only"
    echo "  --simv        Run simulation only"
    echo "  --rtla        Run RTL synthesis only"
    echo "  --restore     Use restore_and_analyze.tcl (skip rtla, continue from saved design)"
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
    echo "  $0 --restore \"Restore from saved design and run power analysis (skip VCS/simv, use restore instead of fresh synthesis)\""
    echo ""
    echo "Note: If any specific step flag is used (--vcs, --simv, etc.), only those steps will run."
    echo "      Use --no-* flags to exclude specific steps from a full run."
    echo "      --restore flag skips VCS/simv and uses restore_and_analyze.tcl instead of fresh rtla.tcl synthesis."
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
        --restore)
            if [ "$SELECTIVE_RUN" = false ]; then
                RUN_VCS=false
                RUN_SIMV=false
                RUN_RTLA=false
                RUN_PRIMEPOWER=false
                RUN_GIT=false
                SELECTIVE_RUN=true
            fi
            USE_RESTORE=true
            RUN_VCS=false
            RUN_SIMV=false
            RUN_RTLA=false
            RUN_PRIMEPOWER=true
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
RTL_CPU_PATH="../cpu"

# Exit on any error and enable error trapping
set -e
trap 'cleanup_on_error' ERR

# Prepare directories
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_BASE_DIR="results"
TEMP_RESULTS_DIR="$RESULTS_BASE_DIR/temp_results_$TIMESTAMP"
FAILED_DIR="$RESULTS_BASE_DIR/failed"

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
# System Top Design Synthesis and Power Analysis Run Metadata
# ==========================================================

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
RTL_CPU_PATH: $RTL_CPU_PATH
TEMP_RESULTS_DIR: $TEMP_RESULTS_DIR

# Tool Versions
# -------------
VCS Version: $(vcs -ID 2>/dev/null | head -1 || echo "VCS not found")
Synopsys Tools: $(which rtl_shell 2>/dev/null || echo "rtl_shell not found")

# Directory Structure
# -------------------
CPU Directory Exists: $([ -d "$RTL_CPU_PATH" ] && echo "Yes" || echo "No")
Config File Exists: $([ -f "config.tcl" ] && echo "Yes" || echo "No")
RTLA Script Exists: $([ -f "rtla.tcl" ] && echo "Yes" || echo "No")
Restore Script Exists: $([ -f "restore_new.tcl" ] && echo "Yes" || echo "No")

# Execution Plan
# --------------
Git Operations: $RUN_GIT
VCS Compilation: $RUN_VCS
Simulation (simv): $RUN_SIMV
RTL Synthesis (rtla): $RUN_RTLA
Power Analysis (PrimePower): $RUN_PRIMEPOWER
Use Restore Mode: $USE_RESTORE

EOF
    
    echo "Run metadata created: $metadata_file"
}

echo "========== System Top Design Synthesis and Power Analysis =========="
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

# Step 1: VCS Compile (for system_top_with_cpu design)
if [ "$RUN_VCS" = true ]; then
    echo "========== STEP 1: VCS Compile (System Top with CPU) =========="
    if [ -d "$RTL_CPU_PATH" ]; then
        pushd "$RTL_CPU_PATH" > /dev/null
        vcs -sverilog -full64 -kdb -debug_access+all  system_top_with_cpu_tb.v +vcs+fsdbon -o simv | tee "../power/$TEMP_RESULTS_DIR/vcs_compile.log"
        echo "VCS compilation completed successfully"
        popd > /dev/null
    else
        echo "Warning: CPU RTL directory not found, skipping VCS compilation"
    fi
else
    echo "========== STEP 1: VCS Compile (SKIPPED) =========="
fi

# Step 2: Run Simulation
if [ "$RUN_SIMV" = true ]; then
    echo "========== STEP 2: Run Simulation =========="
    if [ -d "$RTL_CPU_PATH" ]; then
        pushd "$RTL_CPU_PATH" > /dev/null
        # Run simulation with VCD output for power analysis
        ./simv +fsdb+all=on +fsdb+delta | tee "../power/$TEMP_RESULTS_DIR/simulation.log"
        echo "Simulation completed successfully"
        popd > /dev/null
    else
        echo "Warning: CPU RTL directory not found, skipping simulation"
    fi
else
    echo "========== STEP 2: Run Simulation (SKIPPED) =========="
fi

# Step 3: RTL Synthesis (using proper command)
if [ "$RUN_RTLA" = true ]; then
    echo "========== STEP 3: RTL Synthesis =========="
    
    # Check and optionally remove existing library directory
    LIB_DIR="LIB"
    if [ "$USE_RESTORE" = true ]; then
        echo "Using restore mode - skipping fresh synthesis"
        echo "Will restore from saved design in restore_and_analyze.tcl"
    else
        if [ -d "$LIB_DIR" ]; then
            echo "Library directory '$LIB_DIR' already exists."
            echo "Removing existing library directory before synthesis to avoid errors..."
            rm -rf "$LIB_DIR"
        fi
        
        echo "Running with proper PrimeTime shell command..."
        rtl_shell -f rtla.tcl | tee "$TEMP_RESULTS_DIR/rtl_synthesis.log"
        if [ $? -eq 0 ]; then
            echo "RTL synthesis completed successfully"
        else
            echo "ERROR: RTL synthesis failed - check $TEMP_RESULTS_DIR/rtl_synthesis.log"
            exit 1
        fi
    fi
else
    echo "========== STEP 3: RTL Synthesis (SKIPPED) =========="
fi

# Step 4: Power Analysis (using pwr_shell for power restoration OR restore_and_analyze)
if [ "$RUN_PRIMEPOWER" = true ]; then
    echo "========== STEP 4: Power Analysis =========="
    
    if [ "$USE_RESTORE" = true ]; then
        # Use restore_and_analyze.tcl for continuing from saved design
        if [ -f "restore_and_analyze.tcl" ]; then
            echo "Step 4a: Restoring saved design with rtl_shell..."
            rtl_shell -f restore_and_analyze.tcl | tee "$TEMP_RESULTS_DIR/restore_and_analyze.log"
            if [ $? -eq 0 ]; then
                echo "Design restored and timing analysis completed successfully"
            else
                echo "ERROR: Restore and analysis failed - check $TEMP_RESULTS_DIR/restore_and_analyze.log"
                exit 1
            fi
        else
            echo "ERROR: restore_and_analyze.tcl not found!"
            exit 1
        fi
        
        # Now run pwr_shell for detailed power analysis (same as full flow)
        if [ -f "restore_new.tcl" ]; then
            echo "Step 4b: Running detailed power analysis with pwr_shell..."
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
        # Use regular power analysis flow (after full rtla.tcl synthesis)
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
