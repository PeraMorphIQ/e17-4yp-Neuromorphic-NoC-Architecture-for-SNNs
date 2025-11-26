set_current_mismatch_config auto_fix
set_attribute [get_mismatch_types missing_logical_reference] current_repair(auto_fix) create_blackbox
set_host_options -max_cores 8
set_app_options -list { plan.macro.allow_unmapped_design true}

set search_path "* /tech/45nm/libs/NangateOpenCellLibrary.ndm ../../cpu"
create_lib LIB -ref_libs "NangateOpenCellLibrary" -technology /tech/45nm/cltrls/saed32nm_1p9m_mw.tf
analyze -f sv -vcs "-f src.f "
elaborate system_top_with_cpu
set_top_module system_top_with_cpu

source ./tz_setup.tcl

rtl_opt

set_rtl_power_analysis_options -scenario func@Cmax -design system_top_with_cpu -strip_path system_top_with_cpu_tb/dut -fsdb "../../cpu/novas.fsdb" -output_dir RTLA_WORKSPACE

save_block
save_lib
export_power_data

report_timing > "results/timing_report.txt"
report_timing -max_paths 10 > "results/timing_report_10.txt"
report_area  > "results/area_register.txt"

exit
