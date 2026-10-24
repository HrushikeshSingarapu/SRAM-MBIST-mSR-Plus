#!/usr/bin/env python3
"""
Mutation check: inject one deliberate bug at a time into a COPY of the RTL and
verify that at least one testbench FAILS ("killed"). A mutant that survives
means the testbenches cannot see that class of bug.

Usage (project root):  python3 sim/run_mutation_check.py
Needs iverilog/vvp. The real RTL is never modified.
"""
import os, re, shutil, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

# (name, file, old text, new text)
MUTANTS = [
 ("controller: S11 gets an extra operation", "rtl/bist_controller.sv",
  "S11: max_op_index = 2'd0;", "S11: max_op_index = 2'd1;"),
 ("controller: S12 restart direction down (re-run starts at MAX)", "rtl/bist_controller.sv",
  "if ((state <= S6) || (state == S12))", "if (state <= S6)"),
 ("controller: S8 ascending", "rtl/bist_controller.sv",
  "if (state <= S7)\n                    direction_up = 1'b1;", "if (state <= S8)\n                    direction_up = 1'b1;"),
 ("address gen: descending restart at 0", "rtl/address_generator.sv",
  "else\n                    addr <= {ADDR_WIDTH{1'b1}};", "else\n                    addr <= {ADDR_WIDTH{1'b0}};"),
 ("address gen: wraps instead of holding at last address", "rtl/address_generator.sv",
  "if (!last_addr)\n                        addr <= addr + 1'b1;", "addr <= addr + 1'b1;"),
 ("pattern gen: S9 expects 1 instead of 0", "rtl/pattern_generator.sv",
  "4'd9: begin\n\n                case (operation_index)\n\n                    2'd0: begin\n\n                        mem_read = 1'b1;\n                        expected_data = DATA_ZERO;",
  "4'd9: begin\n\n                case (operation_index)\n\n                    2'd0: begin\n\n                        mem_read = 1'b1;\n                        expected_data = DATA_ONE;"),
 ("pattern gen: S12 last op is r1 instead of r0", "rtl/pattern_generator.sv",
  "2'd2: begin\n\n                        mem_read = 1'b1;\n                        expected_data = DATA_ZERO;",
  "2'd2: begin\n\n                        mem_read = 1'b1;\n                        expected_data = DATA_ONE;"),
 ("comparator: never reports an error", "rtl/data_comparator.sv",
  "compare_error = (sram_data != expected_data);", "compare_error = 1'b0;"),
 ("comparator: X data accepted", "rtl/data_comparator.sv",
  "compare_error = 1'b1;\n        // synthesis translate_on", "compare_error = 1'b0;\n        // synthesis translate_on"),
 ("comparator: compares while not enabled", "rtl/data_comparator.sv",
  "if (compare_enable)\n            compare_error", "if (1'b1)\n            compare_error"),
 ("status monitor: mismatch not latched", "rtl/status_monitor.sv",
  "if (mismatch)\n                fault_detected <= 1'b1;", "fault_detected <= mismatch;"),
 ("status monitor: not cleared by start", "rtl/status_monitor.sv",
  "if (start)\n                fault_detected <= 1'b0;", ""),
 ("top: start accepted while busy", "rtl/mbist_top.sv",
  "assign start_ok = start & ~busy;", "assign start_ok = start;"),
 ("top: SRAM strobes not gated by busy", "rtl/mbist_top.sv",
  ".test_mode(ctrl_busy)", ".test_mode(1'b1)"),
 ("top: pass/fail swapped", "rtl/mbist_top.sv",
  "pass <= ~fault_detected;\n                fail <=  fault_detected;", "pass <=  fault_detected;\n                fail <= ~fault_detected;"),
 ("top: done not sticky-aligned (done one cycle early)", "rtl/mbist_top.sv",
  "assign busy = ctrl_busy | ctrl_done;", "assign busy = ctrl_busy;"),
 ("top: comparator fed the fault-free read data", "rtl/mbist_top.sv",
  ".sram_data(faulty_read_data),", ".sram_data(normal_read_data),"),
 ("sram: write enable ignored for address 0", "rtl/sram_model.sv",
  "if (write_en)\n            mem[write_addr] <= write_data;", "if (write_en && write_addr != 0)\n            mem[write_addr] <= write_data;"),
 ("fault inj: SAF read not forced", "rtl/fault_injection.sv",
  "faulty_read_data  = fv_word;\n                        faulty_write_data = fv_word;", "faulty_write_data = fv_word;"),
 ("fault inj: DRDF returns inverted data (acts like RDF/IRF)", "rtl/fault_injection.sv",
  "DRDF: begin\n                    if (mem_read && is_victim && victim_holds_fv) begin\n                        fault_write_en   = 1'b1;",
  "DRDF: begin\n                    if (mem_read && is_victim && victim_holds_fv) begin\n                        faulty_read_data = ~fv_word;\n                        fault_write_en   = 1'b1;"),
 ("fault inj: CFin behaves like CFid (forces instead of inverts)", "rtl/fault_injection.sv",
  "fault_write_data = ~victim_data;\n                    end\n                end\n\n                //----------------------------------------------\n                // RDF",
  "fault_write_data = fv_word;\n                    end\n                end\n\n                //----------------------------------------------\n                // RDF"),
 ("fault inj: fault_activated stuck at 0", "rtl/fault_injection.sv",
  "fault_activated =\n            (fault_enable &&", "fault_activated =\n            (1'b0 && fault_enable &&"),
]

TESTS = [  # (name, top, pass message, -P args)
 ("address_generator", "tb_address_generator", "ADDRESS GENERATOR TEST PASSED", ["-P", "tb_address_generator.ADDR_WIDTH=3"]),
 ("bist_controller", "tb_bist_controller", "BIST CONTROLLER TEST PASSED", []),
 ("pattern_generator", "tb_pattern_generator", "PATTERN GENERATOR TEST PASSED", []),
 ("data_comparator", "tb_data_comparator", "DATA COMPARATOR TEST PASSED", []),
 ("sram_model", "tb_sram_model", "SRAM MODEL TEST PASSED", []),
 ("fault_injection", "tb_fault_injection", "FAULT INJECTION TEST PASSED", []),
 ("status_monitor", "tb_status_monitor", "STATUS MONITOR TEST PASSED", []),
 ("mbist_top", "tb_mbist_top", "MBIST TOP INTEGRATION TEST PASSED", []),
]

def run_tests(work):
    rtl = sorted(os.path.join(work, "rtl", f) for f in os.listdir(os.path.join(work, "rtl")) if f.endswith(".sv"))
    failed = []
    for name, top, msg, pargs in TESTS:
        vvp = os.path.join(work, top + ".vvp")
        c = subprocess.run(["iverilog", "-g2012", "-I", os.path.join(ROOT, "tb")] + pargs +
                           ["-s", top, "-o", vvp] + rtl + [os.path.join(ROOT, "tb", top + ".sv")],
                           capture_output=True, text=True)
        if c.returncode != 0:
            failed.append(name + "(compile)")
            continue
        try:
            r = subprocess.run(["vvp", vvp], capture_output=True, text=True, timeout=120)
            out = r.stdout + r.stderr
            ok = (r.returncode == 0 and msg in out and not re.search(r"FAILED|^ERROR|FATAL", out, re.M))
        except subprocess.TimeoutExpired:
            ok = False
        if not ok:
            failed.append(name)
    return failed

def main():
    tmp = tempfile.mkdtemp(prefix="mbist_mut_")
    base = os.path.join(tmp, "base")
    shutil.copytree(os.path.join(ROOT, "rtl"), os.path.join(base, "rtl"))
    f = run_tests(base)
    if f:
        print("Baseline (unmutated) RTL already fails:", f); sys.exit(2)
    print("Baseline passes. Running %d mutants...\n" % len(MUTANTS))
    survived = 0
    for i, (name, path, old, new) in enumerate(MUTANTS):
        work = os.path.join(tmp, "m%d" % i)
        shutil.copytree(os.path.join(ROOT, "rtl"), os.path.join(work, "rtl"))
        fp = os.path.join(work, path)
        src = open(fp).read()
        if old not in src:
            print("  [SKIP ] %-62s (pattern not found: update the mutant)" % name); survived += 1; continue
        open(fp, "w").write(src.replace(old, new, 1))
        failed = run_tests(work)
        if failed:
            print("  [KILLED] %-62s by: %s" % (name, ", ".join(failed)))
        else:
            print("  [SURVIVED] %-60s" % name); survived += 1
    shutil.rmtree(tmp, ignore_errors=True)
    print("\n%d mutants, %d killed, %d survived/skipped" % (len(MUTANTS), len(MUTANTS) - survived, survived))
    sys.exit(1 if survived else 0)

main()
