# Load shared configuration
source config.tcl

set_current_mismatch_config auto_fix
set_attribute [get_mismatch_types missing_logical_reference] current_repair(auto_fix) create_blackbox
set_host_options -max_cores $CORES
set_app_options -list { plan.macro.allow_unmapped_design true}

set search_path $SEARCH_PATHS
create_lib $LIB_NAME -ref_libs "$REF_LIBS" -technology $TECH_TF
analyze -f sv -vcs "-f $FILELIST"
elaborate $DESIGN_NAME
set_top_module $TOP_MODULE

source ./tz_setup.tcl

rtl_opt -initial_map_only

set_rtl_power_analysis_options -scenario $SCENARIO_NAME -design $DESIGN_NAME -strip_path $STRIP_PATH -fsdb $FSDB_FILE -output_dir $OUTPUT_DIR

save_block
save_lib
export_power_data

report_timing > "$TEMP_RESULTS_DIR/timing_report.txt"
report_timing -max_paths 10 > "$TEMP_RESULTS_DIR/timing_report_10.txt"
report_area  > "$TEMP_RESULTS_DIR/area_register.txt"

exit
