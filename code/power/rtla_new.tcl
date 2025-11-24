set_current_mismatch_config auto_fix
set_attribute [get_mismatch_types missing_logical_reference] current_repair(auto_fix) create_blackbox
set_host_options -max_cores 8
set_app_options -list { plan.macro.allow_unmapped_design true}

set search_path "* ../libs/NangateOpenCellLibrary.ndm"
create_lib LIB -ref_libs "NangateOpenCellLibrary" -technology ../cltrls/saed32nm_1p9m_mw.tf
analyze -f sv -vcs "-f src.f "
elaborate blackbox
set_top_module blackbox

source ./tz_setup.tcl

rtl_opt -initial_map_only

set_rtl_power_analysis_options -scenario func@cworst -design blackbox -strip_path blackbox_tb/uut -fsdb "../../../../rtl/blackbox/novas.fsdb"  -output_dir RTLA_WORKSPACE

save_block
save_lib
export_power_data

report_timing > "results/timing_report.txt"
report_timing -max_paths 10 > "results/timing_report_10.txt"
report_area  > "results/area_register.txt"

exit
