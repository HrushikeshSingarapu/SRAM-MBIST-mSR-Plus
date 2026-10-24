@echo off
setlocal enabledelayedexpansion
rem ============================================================
rem Runs EVERY testbench in Vivado xsim and prints one PASS/FAIL
rem line per testbench plus a final verdict.
rem Put this file in the project root (the folder containing rtl\ and tb\)
rem and double-click it, or run:  run_all_tb.bat
rem Optional: set VIVADO_BIN=C:\Xilinx\2025.1\Vivado\bin  before running.
rem Full logs are written to sim_logs\<tb>.log
rem ============================================================
cd /d "%~dp0"

rem ---- locate Vivado bin ----
set XV=
where xvlog.bat >nul 2>nul && set XV=
if not defined VIVADO_BIN (
  for /d %%D in ("C:\Xilinx\Vivado\*" "C:\Xilinx\*\Vivado" "D:\Xilinx\Vivado\*" "D:\Xilinx\*\Vivado" "D:\*\*\Vivado") do (
    if exist "%%~D\bin\xvlog.bat" set "VIVADO_BIN=%%~D\bin"
  )
)
if defined VIVADO_BIN (set "XV=%VIVADO_BIN%\") else (set "XV=")
where xvlog.bat >nul 2>nul || if not exist "%XV%xvlog.bat" (
  echo Could not find xvlog.bat. Set VIVADO_BIN to your Vivado "bin" folder, e.g.
  echo   set VIVADO_BIN=C:\Xilinx\2025.1\Vivado\bin
  exit /b 1
)

set RTL=rtl\address_generator.sv rtl\bist_controller.sv rtl\data_comparator.sv rtl\fault_injection.sv rtl\fault_logger.sv rtl\pass_fail_indicator.sv rtl\pattern_generator.sv rtl\sram_model.sv rtl\status_monitor.sv rtl\test_mode_control.sv rtl\mbist_top.sv

if not exist sim_logs mkdir sim_logs
set NFAIL=0

for %%T in (tb_address_generator tb_bist_controller tb_pattern_generator tb_data_comparator tb_sram_model tb_fault_injection tb_status_monitor tb_fault_logger tb_pass_fail_indicator tb_test_mode_control tb_mbist_top tb_fault_coverage) do (
  set "OK=0"
  call "%XV%xvlog.bat" -sv %RTL% tb\%%T.sv > sim_logs\%%T.log 2>&1
  call "%XV%xelab.bat" --timescale 1ns/1ps -s snap_%%T %%T >> sim_logs\%%T.log 2>&1
  call "%XV%xsim.bat" snap_%%T -runall >> sim_logs\%%T.log 2>&1
  findstr /R /C:"TEST PASSED" /C:"TEST 5 PASSED" /C:"FAULT COVERAGE RUN COMPLETED" sim_logs\%%T.log >nul && set "OK=1"
  findstr /R /C:"FAILED" /C:"ERROR:" /C:"FATAL" /C:"FALSE ALARM" sim_logs\%%T.log >nul && set "OK=0"
  if "!OK!"=="1" (echo PASS  %%T) else (echo FAIL  %%T   ^(see sim_logs\%%T.log^) & set /a NFAIL+=1)
)

echo.
if %NFAIL%==0 (echo ALL TESTBENCHES PASSED) else (echo %NFAIL% TESTBENCH^(ES^) FAILED)
endlocal
