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
RTL_MESH_PATH="../../accelerator/mesh"

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
        echo "Failed results saved in $FAILED_DIR for debugging"
    fi
    
    # Clean up any partial library files
    if [ -d "mesh_LIB" ]; then
        echo "Removing partial library directory"
        rm -rf "mesh_LIB"
    fi
    
    echo "========== CLEANUP COMPLETE - FAILED RESULTS SAVED IN $FAILED_DIR =========="
    exit 1
}

# Create temporary results directory for this run  
mkdir -p "$TEMP_RESULTS_DIR"

# Export TEMP_RESULTS_DIR as environment variable for TCL scripts to use
export TEMP_RESULTS_DIR

# Create run metadata file
create_run_metadata() {
    local metadata_file="$TEMP_RESULTS_DIR/run_metadata.txt"
    
    cat > "$metadata_file" << EOF
# Mesh Design Synthesis and Power Analysis Run Metadata
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
RTL_MESH_PATH: $RTL_MESH_PATH
TEMP_RESULTS_DIR: $TEMP_RESULTS_DIR

# Tool Versions
# -------------
VCS Version: $(vcs -ID 2>/dev/null | head -1 || echo "VCS not found")
Synopsys Tools: $(which rtl_shell 2>/dev/null || echo "rtl_shell not found")

# Directory Structure
# -------------------
Mesh Directory Exists: $([ -d "$RTL_MESH_PATH" ] && echo "Yes" || echo "No")
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

EOF
    
    echo "Run metadata created: $metadata_file"
}

echo "========== Mesh Design Synthesis and Power Analysis =========="
echo "Description: $RUN_DESCRIPTION"
echo "Using temporary results directory: $TEMP_RESULTS_DIR"
echo "Environment variable TEMP_RESULTS_DIR exported for TCL scripts"

# Display execution plan
echo "========== EXECUTION PLAN =========="
echo "Steps that will be executed:"
if [ "$RUN_GIT" = true ]; then
    echo "  ✓ Git operations (pull, commit, push)"
else
    echo "  ✗ Git operations (SKIPPED)"
fi
if [ "$RUN_VCS" = true ]; then
    echo "  ✓ VCS compilation"
else
    echo "  ✗ VCS compilation (SKIPPED)"
fi
if [ "$RUN_SIMV" = true ]; then
    echo "  ✓ Simulation (simv)"
else
    echo "  ✗ Simulation (SKIPPED)"
fi
if [ "$RUN_RTLA" = true ]; then
    echo "  ✓ RTL synthesis (rtla)"
else
    echo "  ✗ RTL synthesis (SKIPPED)"
fi
if [ "$RUN_PRIMEPOWER" = true ]; then
    echo "  ✓ Power analysis (PrimePower)"
else
    echo "  ✗ Power analysis (SKIPPED)"
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

# Step 1: VCS Compile (for mesh design)
if [ "$RUN_VCS" = true ]; then
    echo "========== STEP 1: VCS Compile (Mesh) =========="
    if [ -d "$RTL_MESH_PATH" ]; then
        pushd "$RTL_MESH_PATH" > /dev/null
        vcs -sverilog -full64 -kdb -debug_access+all -f ../../power/power_v4/mesh_sim.f mesh_tb.v +vcs+fsdbon -o simv | tee "../../power/power_v4/$TEMP_RESULTS_DIR/vcs_compile.log"
        echo "VCS compilation completed successfully"
        popd > /dev/null
    else
        echo "Warning: Mesh RTL directory not found at $RTL_MESH_PATH, skipping VCS compilation"
    fi
else
    echo "========== STEP 1: VCS Compile (SKIPPED) =========="
fi

# Step 2: Run Simulation
if [ "$RUN_SIMV" = true ]; then
    echo "========== STEP 2: Run Simulation =========="
    if [ -d "$RTL_MESH_PATH" ]; then
        pushd "$RTL_MESH_PATH" > /dev/null
        
        # Remove old FSDB file if it exists
        if [ -f "novas.fsdb" ]; then
            rm "novas.fsdb"
        fi
        
        ./simv +fsdb+all=on +fsdb+delta | tee "../../power/power_v4/$TEMP_RESULTS_DIR/simulation.log"
        
        if [ -f "novas.fsdb" ]; then
            echo "Simulation completed successfully, novas.fsdb generated"
        else
            echo "WARNING: novas.fsdb was not generated!"
        fi
        
        popd > /dev/null
    else
        echo "Warning: Mesh RTL directory not found at $RTL_MESH_PATH, skipping simulation"
    fi
else
    echo "========== STEP 2: Run Simulation (SKIPPED) =========="
fi

# Step 3: RTL Synthesis (using proper command)
if [ "$RUN_RTLA" = true ]; then
    echo "========== STEP 3: RTL Synthesis =========="
    
    # Check and optionally remove existing library directory
    LIB_DIR="mesh_LIB"
    if [ -d "$LIB_DIR" ]; then
        echo "Library directory '$LIB_DIR' already exists."
        echo "Removing existing library directory before synthesis to avoid errors..."
        rm -rf "$LIB_DIR"
    fi

    # Remove TZ_OUTDIR to ensure clean power analysis data
    if [ -d "TZ_OUTDIR" ]; then
        echo "Removing existing TZ_OUTDIR to ensure clean power analysis data..."
        rm -rf "TZ_OUTDIR"
    fi
    
    echo "Running with proper PrimeTime shell command..."
    rtl_shell -f rtla.tcl | tee "$TEMP_RESULTS_DIR/rtl_synthesis.log"
    if [ $? -eq 0 ]; then
        echo "RTL synthesis completed successfully"
    else
        echo "ERROR: RTL synthesis failed - check $TEMP_RESULTS_DIR/rtl_synthesis.log"
        exit 1
    fi
else
    echo "========== STEP 3: RTL Synthesis (SKIPPED) =========="
fi

# Step 4: Power Analysis (using proper command)
if [ "$RUN_PRIMEPOWER" = true ]; then
    echo "========== STEP 4: Power Analysis =========="
    if [ -f "restore_alternative.tcl" ]; then
        echo "Running alternative power analysis (skipping compute_metrics)..."
        pwr_shell -f restore_alternative.tcl | tee "$TEMP_RESULTS_DIR/power_restore.log" 
        if [ $? -eq 0 ]; then
            echo "Power analysis completed successfully"
        else
            echo "ERROR: Power analysis failed - check $TEMP_RESULTS_DIR/power_restore.log"
            exit 1
        fi
    else
        echo "Warning: restore_alternative.tcl not found, skipping power analysis"
    fi
else
    echo "========== STEP 4: Power Analysis (SKIPPED) =========="
fi

# Step 5: Save successful results (only if execution was successful)
echo "========== STEP 5: Saving Successful Results =========="

# Create results base directory if it doesn't exist
mkdir -p "$RESULTS_BASE_DIR"

# Move temporary results to timestamped subdirectory in results
FINAL_RESULTS_DIR="$RESULTS_BASE_DIR/$TIMESTAMP"
mv "$TEMP_RESULTS_DIR" "$FINAL_RESULTS_DIR"
echo "Successful results saved to: $FINAL_RESULTS_DIR"

# Clean up any old temporary files
echo "Cleaning up old temporary files..."
rm -rf temp_results_* 2>/dev/null || true
echo "Temporary files cleaned up"

# Step 6: Git Commit and Push (allow git operations to fail without stopping script)
if [ "$RUN_GIT" = true ]; then
    echo "========== STEP 6: Git Commit and Push =========="
    set +e  # Temporarily disable exit on error for git operations

    if git add .; then
        echo "Files staged successfully"
    else
        echo "Warning: Failed to stage some files"
    fi

    if git commit -m "Auto commit: $RUN_DESCRIPTION - $TIMESTAMP"; then
        echo "Commit created successfully"
    else
        echo "Warning: Commit failed (possibly no changes to commit)"
    fi

    if git pull --rebase --autostash origin main | tee "$FINAL_RESULTS_DIR/git_pull_before_push.log"; then
        echo "Git pull completed"
    else
        echo "Warning: Git pull failed"
    fi

    if git push | tee "$FINAL_RESULTS_DIR/git_push.log"; then
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
echo "Results and logs are saved in: $FINAL_RESULTS_DIR"

# Final cleanup - remove any remaining temporary files or directories
echo "Performing final cleanup..."
rm -rf temp_results_* 2>/dev/null || true
echo "Final cleanup completed"

echo "========== SYNTHESIS AND ANALYSIS COMPLETE =========="

