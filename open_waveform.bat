@echo off
echo ============================================================
echo Opening SRAM MBIST mSR+ Waveforms in Vivado GUI...
echo ============================================================

set VIVADO_BIN=D:\fardin\2025.2\Vivado\bin

if not exist "mbist_top_wave.wdb" (
    echo [INFO] Generating waveform database mbist_top_wave.wdb...
    call "%VIVADO_BIN%\xvlog.bat" -sv rtl/address_generator.sv rtl/bist_controller.sv rtl/data_comparator.sv rtl/fault_injection.sv rtl/fault_logger.sv rtl/pass_fail_indicator.sv rtl/pattern_generator.sv rtl/sram_model.sv rtl/status_monitor.sv rtl/test_mode_control.sv rtl/mbist_top.sv tb/tb_mbist_top.sv
    call "%VIVADO_BIN%\xelab.bat" --timescale 1ns/1ps --debug all -s sim_top_wave tb_mbist_top
    echo log_wave -recursive * > gen_wave_tmp.tcl
    echo run -all >> gen_wave_tmp.tcl
    echo exit >> gen_wave_tmp.tcl
    call "%VIVADO_BIN%\xsim.bat" sim_top_wave -tclbatch gen_wave_tmp.tcl -wdb mbist_top_wave.wdb
    del gen_wave_tmp.tcl
)

echo.
echo Launching Vivado Waveform Viewer...
call "%VIVADO_BIN%\xsim.bat" mbist_top_wave.wdb -view mbist_top_waveform.wcfg -gui
