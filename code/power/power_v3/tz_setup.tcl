set_app_options -list {compile.flow.enable_multibit true}
set_app_options -name shell.dc_compatibility.return_tcl_errors  -value false
set_app_options -name compile.flow.autoungroup -value false
set_clock_gating_options -minimum_bitwidth 1

read_parasitic_tech -tlup /tech/45nm/cltrls/saed32nm_1p9m_Cmax.tluplus -layermap /tech/45nm/cltrls/saed32nm_tf_itf_tluplus.map -name Cmax
read_parasitic_tech -tlup /tech/45nm/cltrls/saed32nm_1p9m_Cmin.tluplus -layermap /tech/45nm/cltrls/saed32nm_tf_itf_tluplus.map -name Cmin

set_attribute -objects [get_cells -hier -filter "ref_name=~*SELECT_OP*"] -name map_to_mux -value true
set_app_options -name compile.datapath.ungroup -value false
set_app_options -as_user_default -list {ungr.dw.hlo_enable_dw_ungrp false}

set_clock_gating_options -max_fanout 8 -max_number_of_levels  2
set_clock_gate_style -target { pos_edge_flip_flop } -test_point before

set_app_options -name compile.flow.enable_multibit -value true

set_app_option -name  rtl_opt.conditioning.disable_boundary_optimization_and_auto_ungrouping -value true

set_app_options -as_user_default -list {compile.flow.autoungroup false}
set_app_options -as_user_default -list {compile.flow.boundary_optimization false}
#set_app_options -as_user_default -list {compile.flow.constant_and_unloaded_propagation_with_no_boundary_opt false}


create_mode func

create_corner Cmax
create_corner Cmin

create_scenario -mode func -corner Cmax -name func@Cmax
create_scenario -mode func -corner Cmin -name func@Cmin

set_parasitic_parameters -corner Cmin -late_spec Cmin -early_spec Cmin
set_parasitic_parameters -corner Cmax -late_spec Cmax -early_spec Cmax

set_scenario_status [list func@Cmax func@Cmin] -hold false




current_scenario func@Cmin

source ./sdc/clocks.sdc


report_scenarios
