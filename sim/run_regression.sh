#!/usr/bin/env bash
#============================================================
# Regression for the SRAM MBIST (March mSR+) project.
# Simulator: Icarus Verilog 12 (iverilog -g2012 / vvp).
#
#   sim/run_regression.sh          unit tests + top-level tests
#                                  (several width configurations)
#   sim/run_regression.sh --full   additionally the exhaustive
#                                  fault-coverage run (3 memory
#                                  power-up states, ~1 minute)
#   sim/run_regression.sh --cov4   exhaustive coverage with
#                                  ADDR_WIDTH=4 (16 cells, slow)
#
# Run from the project root. Exit code != 0 if anything fails.
#============================================================
set -u
cd "$(dirname "$0")/.."

OUT=${OUT:-/tmp/mbist_sim}
mkdir -p "$OUT"
RTL=$(ls rtl/*.sv)
FAILS=0
PASSES=0

# run <name> <top> <passmsg> [iverilog -P options...]
run() {
    local name=$1 top=$2 msg=$3; shift 3
    local vvp="$OUT/$name.vvp" log="$OUT/$name.log"
    if ! iverilog -g2012 "$@" -s "$top" -o "$vvp" $RTL tb/$top.sv >"$log.compile" 2>&1; then
        echo "FAIL  $name  (compile error, see $log.compile)"; FAILS=$((FAILS+1)); return
    fi
    vvp "$vvp" >"$log" 2>&1
    local rc=$?
    if [ $rc -eq 0 ] && grep -q "$msg" "$log" && ! grep -q -E "FAILED|^ERROR|TB ERROR|FATAL" "$log"; then
        echo "PASS  $name"; PASSES=$((PASSES+1))
    else
        echo "FAIL  $name  (see $log)"; FAILS=$((FAILS+1))
    fi
}

echo "== unit tests =="
run address_generator_w3 tb_address_generator "ADDRESS GENERATOR TEST PASSED" -P tb_address_generator.ADDR_WIDTH=3
run address_generator_w4 tb_address_generator "ADDRESS GENERATOR TEST PASSED" -P tb_address_generator.ADDR_WIDTH=4
run address_generator_w5 tb_address_generator "ADDRESS GENERATOR TEST PASSED" -P tb_address_generator.ADDR_WIDTH=5
run bist_controller      tb_bist_controller   "BIST CONTROLLER TEST PASSED"
run pattern_generator    tb_pattern_generator "PATTERN GENERATOR TEST PASSED"
run data_comparator      tb_data_comparator   "DATA COMPARATOR TEST PASSED"
run sram_model           tb_sram_model        "SRAM MODEL TEST PASSED"
run fault_injection      tb_fault_injection   "FAULT INJECTION TEST PASSED"
run status_monitor       tb_status_monitor    "STATUS MONITOR TEST PASSED"
run fault_logger         tb_fault_logger      "PASSED"
run pass_fail_indicator  tb_pass_fail_indicator "PASSED"
run test_mode_control    tb_test_mode_control "PASSED"

echo "== top-level integration (golden March mSR+ stream + faults) =="
run mbist_top_a3_d8   tb_mbist_top "MBIST TOP INTEGRATION TEST PASSED" -P tb_mbist_top.ADDR_WIDTH=3 -P tb_mbist_top.DATA_WIDTH=8
run mbist_top_a4_d32  tb_mbist_top "MBIST TOP INTEGRATION TEST PASSED" -P tb_mbist_top.ADDR_WIDTH=4 -P tb_mbist_top.DATA_WIDTH=32
run mbist_top_a2_d1   tb_mbist_top "MBIST TOP INTEGRATION TEST PASSED" -P tb_mbist_top.ADDR_WIDTH=2 -P tb_mbist_top.DATA_WIDTH=1
run mbist_top_a5_d16  tb_mbist_top "MBIST TOP INTEGRATION TEST PASSED" -P tb_mbist_top.ADDR_WIDTH=5 -P tb_mbist_top.DATA_WIDTH=16

if [ "${1:-}" = "--full" ] || [ "${1:-}" = "--cov4" ]; then
    echo "== exhaustive fault coverage (RTL vs behavioural March engine) =="
    if [ "${1:-}" = "--cov4" ]; then
        run fault_coverage_a4 tb_fault_coverage "FAULT COVERAGE RUN COMPLETED" -P tb_fault_coverage.ADDR_WIDTH=4
        cp "$OUT/fault_coverage_a4.log" "$OUT/coverage_report.txt"
    else
        run fault_coverage_a3 tb_fault_coverage "FAULT COVERAGE RUN COMPLETED" -P tb_fault_coverage.ADDR_WIDTH=3
        cp "$OUT/fault_coverage_a3.log" "$OUT/coverage_report.txt"
    fi
    echo "coverage report: $OUT/coverage_report.txt"
fi

echo
echo "passed: $PASSES   failed: $FAILS"
[ $FAILS -eq 0 ]
