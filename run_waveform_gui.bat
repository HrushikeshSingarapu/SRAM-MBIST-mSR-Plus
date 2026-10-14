@echo off
echo ============================================================
echo Compiling and Launching Vivado Waveform GUI for MBIST Top...
echo ============================================================

set VIVADO_BIN=D:\fardin\2025.2\Vivado\bin

echo [1/2] Compiling design and testbench...
call "%VIVADO_BIN%\xvlog.bat" -sv rtl/address_generator.sv rtl/bist_controller.sv rtl/data_comparator.sv rtl/fault_injection.sv rtl/fault_logger.sv rtl/pass_fail_indicator.sv rtl/pattern_generator.sv rtl/sram_model.sv rtl/status_monitor.sv rtl/test_mode_control.sv rtl/mbist_top.sv tb/tb_mbist_top.sv

echo [2/2] Elaborating simulation snapshot with debug waveforms...
call "%VIVADO_BIN%\xelab.bat" --timescale 1ns/1ps --debug all -s sim_top_wave tb_mbist_top

if not exist "xsim.dir\sim_top_wave\xsimk.exe" (
    echo [ERROR] Simulation elaboration failed to generate executable.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo Compilation successful! Launching Vivado Waveform GUI...
echo ============================================================
call "%VIVADO_BIN%\xsim.bat" sim_top_wave -gui -view mbist_top_waveform.wcfg
