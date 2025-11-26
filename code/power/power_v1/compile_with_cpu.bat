@echo off
REM Compilation script for system_top_with_cpu.v
REM Uses module library paths to avoid duplicate declarations

echo ================================================
echo Compiling system_top_with_cpu.v
echo ================================================

cd /d "%~dp0..\cpu"

REM Clean previous build
if exist build\system_top_with_cpu.vvp del build\system_top_with_cpu.vvp
if not exist build mkdir build

echo.
echo [1/2] Compiling design...

REM Change to a clean directory to avoid include path issues
cd "%~dp0"

REM Strategy: Include all submodules first, then use _no_includes versions
REM This avoids duplicate declarations

iverilog -g2012 ^
    -I ../cpu/fpu ^
    -I ../cpu/noc ^
    -I ../cpu/neuron_bank ^
    -I ../cpu/cpu/zicsr ^
    ../cpu/support_modules/mux_2to1_32bit.v ^
    ../cpu/support_modules/mux_2to1_3bit.v ^
    ../cpu/support_modules/mux_4to1_32bit.v ^
    ../cpu/support_modules/plus_4_adder.v ^
    "../cpu/fpu/Priority Encoder.v" ^
    ../cpu/fpu/Addition-Subtraction_no_includes.v ^
    ../cpu/fpu/Multiplication_no_includes.v ^
    ../cpu/fpu/Division_no_includes.v ^
    ../cpu/fpu/Iteration.v ^
    ../cpu/fpu/Comparison.v ^
    ../cpu/fpu/Converter.v ^
    ../cpu/fpu/fpu_no_includes.v ^
    ../cpu/f_alu/f_alu.v ^
    ../cpu/alu/alu.v ^
    ../cpu/reg_file/reg_file.v ^
    ../cpu/f_reg_file/f_reg_file.v ^
    ../cpu/immediate_generation_unit/immediate_generation_unit.v ^
    ../cpu/immediate_select_unit/immediate_select_unit.v ^
    ../cpu/control_unit/control_unit_no_includes.v ^
    ../cpu/branch_control_unit/branch_control_unit.v ^
    ../cpu/forwarding_units/ex_forward_unit.v ^
    ../cpu/forwarding_units/mem_forward_unit.v ^
    ../cpu/hazard_detection_unit/hazard_detection_unit.v ^
    ../cpu/pipeline_flush_unit/pipeline_flush_unit.v ^
    ../cpu/pipeline_registers/pr_if_id.v ^
    ../cpu/pipeline_registers/pr_id_ex.v ^
    ../cpu/pipeline_registers/pr_ex_mem.v ^
    ../cpu/pipeline_registers/pr_mem_wb.v ^
    ../cpu/cpu/cpu_no_includes.v ^
    ../cpu/noc/async_fifo.v ^
    ../cpu/noc/input_router.v ^
    ../cpu/noc/rr_arbiter.v ^
    ../cpu/noc/virtual_channel.v ^
    ../cpu/noc/input_module_no_includes.v ^
    ../cpu/noc/output_module_no_includes.v ^
    ../cpu/noc/router_no_includes.v ^
    ../cpu/noc/network_interface_no_includes.v ^
    ../cpu/neuron_bank/rng.v ^
    ../cpu/neuron_bank/neuron_core.v ^
    ../cpu/neuron_bank/neuron_bank_no_includes.v ^
    ../cpu/system_top_with_cpu.v ^
    -o ../cpu/build/system_top_with_cpu.vvp 2>&1

if errorlevel 1 (
    echo.
    echo [ERROR] Compilation failed!
    echo.
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Compilation completed!
echo Output: build\system_top_with_cpu.vvp
echo.
echo [2/2] Would you like to run the testbench? (Y/N^)
echo Press any key to continue to testbench creation...
pause > nul

echo.
echo Next step: Create testbench for system_top_with_cpu_tb.v
echo.
