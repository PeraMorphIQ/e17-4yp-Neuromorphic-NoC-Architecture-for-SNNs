@echo off
REM Compilation script for system_top_with_cpu testbench
echo ========================================
echo COMPILING system_top_with_cpu TESTBENCH  
echo ========================================
echo.

cd /d %~dp0

iverilog -g2012 ^
-y fpu -y noc -y neuron_bank -y cpu -y support_modules -y alu -y reg_file -y f_reg_file -y f_alu ^
-y immediate_generation_unit -y immediate_select_unit -y control_unit -y branch_control_unit ^
-y hazard_detection_unit -y forwarding_units -y pipeline_flush_unit -y pipeline_registers -y zicsr ^
-I fpu -I noc -I neuron_bank -I cpu -I zicsr ^
system_top_with_cpu.v testbench/system_top_with_cpu_tb.v ^
-o build/system_top_with_cpu_tb.vvp

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ======================================== 
    echo COMPILATION SUCCESSFUL!
    echo ========================================
    echo.
    echo Running simulation...
    vvp build/system_top_with_cpu_tb.vvp
) else (
    echo.
    echo ========================================
    echo COMPILATION FAILED!
    echo ========================================
)

pause
