@echo off
echo ============================================================
echo Compiling and Launching Vivado Waveform GUI for MBIST Top...
echo ============================================================

set VIVADO_BIN=D:\fardin\2025.2\Vivado\bin

call "%VIVADO_BIN%\xvlog.bat" -sv rtl/address_generator.sv rtl/bist_controller.sv rtl/data_comparator.sv rtl/fault_injection.sv rtl/fault_logger.sv rtl/pass_fail_indicator.sv rtl/pattern_generator.sv rtl/sram_model.sv rtl/status_monitor.sv rtl/test_mode_control.sv rtl/mbist_top.sv tb/tb_mbist_top.sv
if %ERRORLEVEL% neq 0 goto error

call "%VIVADO_BIN%\xelab.bat" --timescale 1ns/1ps --debug all -s sim_top_wave tb_mbist_top
if %ERRORLEVEL% neq 0 goto error

echo Launching Vivado Simulator Waveform Viewer...
call "%VIVADO_BIN%\xsim.bat" sim_top_wave -gui
goto end

:error
echo An error occurred during compilation or elaboration.
pause

:end
