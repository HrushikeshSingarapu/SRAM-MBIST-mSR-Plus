# Change log (audit and fix of the SRAM MBIST / March mSR+ project)

Baseline = the `MBIST_SV_Complete` archive (which already contained `mbist_top`
and `fault_injection`, unlike the GitHub snapshot at that time).
Nothing was committed or pushed.

## RTL

| File | Change | Why |
|---|---|---|
| `rtl/bist_controller.sv` | `restart_direction_up` is now **1 for S12** (was 0). | After S12 the address generator was restarted at MAX, so a second test without reset started S0 at address MAX and only covered one cell. The sequence/step logic itself was already correct. |
| `rtl/data_comparator.sv` | X/Z read data is treated as a **mismatch** in simulation (inside `translate_off/on`). Synthesised logic unchanged. | Previously X data gave `compare_error = X`, which `status_monitor` silently treated as "no mismatch". |
| `rtl/sram_model.sv` | New verification-only read port `aggr_read_addr / aggr_read_data`; comments on read/write timing and un-initialised contents. | Coupling faults depend on the aggressor cell's content. No behaviour change on the existing ports. |
| `rtl/fault_injection.sv` | **Rewritten.** Standard functional-fault-model definitions for SAF, TF, CFid, CFdrd, CFin, RDF, DRDF, IRF, CFtr, CFwd, WDF; two extra *paper-literal* readings (`CFDRD_P`=11, `CFWD_P`=12); new inputs `aggressor_data`, `fault_variant`; new output `fault_activated`. History registers removed. | Old models were not faithful: CFID and CFIN were the same code; RDF/DRDF/IRF never modified the cell; WDF inverted every write; DRDF fired only on a repeated read; coupling faults fired on every aggressor access regardless of transition or state; faults could not be parameterised, so coverage could not be measured. |
| `rtl/mbist_top.sv` | (1) SRAM strobes gated by `busy` through the (previously unused) `test_mode_control`. (2) `done` is now registered together with `pass/fail` and held until the next start; `busy` covers the controller's DONE cycle. (3) `start` is ignored while busy (`start_ok`). (4) new ports `fault_variant`; aggressor data path. | (1) `pattern_generator` decodes `march_step = 0` as S0, so the controller's idle/done state wrote `00` into the SRAM. (2) `done` used to rise one clock **before** `pass/fail` were valid, which is why the original testbench printed "No-fault MBIST failed". (3) A start pulse in mid-test cleared an already latched mismatch. |

Unchanged RTL: `address_generator`, `pattern_generator`, `status_monitor`,
`fault_logger`, `pass_fail_indicator`, `test_mode_control` (only line endings
may differ). `pass_fail_indicator` and `fault_logger` are still not
instantiated in `mbist_top`; they remain stand-alone, unit-tested blocks.

## Testbenches

| File | Change |
|---|---|
| `tb/tb_mbist_top.sv` | **Rewritten** and now self-checking. The old one only printed; it could not fail the simulation. Checks the full 22-ops/cell stream against an independent copy of the paper's Table II/III (kind, address, data, step), idle accesses, busy continuity, done/pass/fail timing, fault ACTIVATION before DETECTION, re-run, spurious start, mid-test reset. Parameterised (`ADDR_WIDTH`, `DATA_WIDTH`). |
| `tb/tb_fault_injection.sv` | **Rewritten**: 106 directed trigger / non-trigger cases. The old one had no checks at all. |
| `tb/tb_fault_coverage.sv` | **New.** Exhaustive coverage over all models, variants, victims and aggressor/victim pairs, 3 power-up states, cross-checked per instance against an independent behavioural March engine (also runs March mSR, MATS++, March C-). |
| `tb/tb_bist_controller.sv` | **Rewritten**: every controller output compared cycle by cycle against the paper reference for 4 addresses, plus re-run and mid-test reset. (The old version did not compile in Icarus and used a constant `last_addr`.) |
| `tb/tb_pattern_generator.sv` | **Rewritten**: table-driven against the paper reference for two data widths; `$error` calls that never failed the run are gone. |
| `tb/tb_address_generator.sv` | Extended: parameterised width, full ascending and descending sweeps, holds at the ends, restart priority. |
| `tb/tb_data_comparator.sv` | Now fails the run on any error; adds X/Z cases and single-bit differences. |
| `tb/tb_sram_model.sv` | Adds the aggressor port, X-at-power-up, read-during-write, write-enable, fault-write priority. |
| `tb/tb_status_monitor.sv`, `tb_fault_logger.sv`, `tb_pass_fail_indicator.sv`, `tb_test_mode_control.sv` | Unchanged (already self-checking). |

## Scripts / docs (new)

* `sim/run_regression.sh` - runs everything (Icarus Verilog). `--full` adds the exhaustive coverage run.
* `sim/run_mutation_check.py` - injects 22 deliberate bugs, one at a time, into a copy of the RTL and verifies a testbench catches each.
* `docs/VERIFICATION_REPORT.md`, `docs/coverage_report_8cells.txt`, `docs/coverage_report_16cells.txt`.

## Update: paper-literal WDF model and paper-style summary

* `rtl/fault_injection.sv`: new model `WDF_P` (fault_type 13): any access to the
  aggressor word line flips a victim holding fv (paper Table I: word-line
  activation disturbs nearby word lines). No other model changed.
* `tb/tb_fault_injection.sv`: 116 directed cases (8 new for WDF_P).
* `tb/tb_fault_coverage.sv`: covers WDF_P (14 models, 1552 instances per
  power-up state); the mSR+ engine table is now written out literally;
  prints a paper-style table of the paper's 11 fault models.
* `docs/FAULT_MODEL_MAPPING.md`: mapping, results and the list of what does
  and does not match the paper.
* `run_all_tb.bat`: runs every testbench in Vivado xsim, one PASS/FAIL line each.
