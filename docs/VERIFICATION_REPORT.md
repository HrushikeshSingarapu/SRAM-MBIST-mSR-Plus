# Verification report - SRAM MBIST IP core, March mSR+

Everything below was **observed** by simulation with Icarus Verilog 12
(`sim/run_regression.sh --full`) unless it says otherwise. Vivado/xsim and
Basys 3 hardware were **not** available in the audit environment.

Reference paper: M.-Y. Lin, W.-K. Chiang, C.-H. Wang, *Enhancing Memory BIST With
an Optimized RTL-BIST IP Core*, IEEE TVLSI vol. 33 no. 9, Sept. 2025.

## 1. Executive summary

* The algorithm implemented in RTL is **exactly** the paper's March mSR+
  (13 elements S0-S12, 22 operations per cell). Verified: the operations that
  reach the SRAM (kind, address, data, element) are compared with an independent
  transcription of Tables II/III for 4, 8, 16 and 32 cells and several data widths.
* The reported "No-fault MBIST failed" was **not an RTL algorithm bug**: `done` rose one
  clock before `pass/fail` were registered and the testbench sampled in between.
  Fixed in `mbist_top` (done/pass/fail now rise together) - the algorithm was fine.
* Real RTL bugs found and fixed: idle-state SRAM writes, second run starting at the wrong
  address, spurious `start` clearing a latched failure, X data accepted by the
  comparator, and fault models that did not implement the faults they were named after.
* The old integration testbench could not fail (it only printed). The new testbenches
  fail the simulation on any violation; 22/22 injected RTL mutants are caught.
* Fault coverage of March mSR+ (exhaustive, 8 and 16 cells, 3 power-up states) is
  reported in section 4. **It does not reproduce every number in the paper** - see section 5.

## 2. Bugs (confirmed by simulation)

1. **Testbench/`done` timing** - `mbist_top.sv`, `tb_mbist_top.sv`.
   Observed: all 12 tests printed FAIL although a diagnostic run showed 0 mismatches and
   `pass=1` two cycles after `done`. Cause: `done` (combinational from the controller's
   DONE state) preceded the registered `pass/fail`. Correction: `done` is registered
   with `pass/fail` and held until the next start.
2. **SRAM written while idle/done** - `pattern_generator` + `bist_controller`.
   Observed: 9 writes of `00` while `busy=0`. Cause: `march_step=0` is also the idle
   code. Correction: strobes gated by `busy` (`test_mode_control`).
3. **Re-run without reset** - `bist_controller.restart_direction_up`.
   S12 left the address at MAX. Corrected; tested by "second run without reset".
4. **Spurious start** - a start pulse in mid-test cleared `fault_detected`. Now ignored.
   The mutant that removes this gating is caught only by a pulse placed after the last
   mismatch (test 6).
5. **X data accepted** - `data_comparator` produced X, treated as "no mismatch".
6. **Fault models** - see `docs/CHANGES.md`. The old CFID and CFIN were identical code.

Not a bug but worth knowing: in the original code `pass_fail_indicator`,
`fault_logger` were never instantiated; `test_mode_control` now is.

## 3. Paper-to-RTL traceability

| Paper item | RTL | Evidence |
|---|---|---|
| 13 elements S0-S12, ops per Table II/III, 22N | `bist_controller`, `pattern_generator` | `tb_pattern_generator` (all 22 ops, 2 widths), `tb_bist_controller` (every output, every cycle), `tb_mbist_top` golden stream |
| Up S0-S7, down S8-S12; S8 starts at MAX | `bist_controller`, `address_generator` | `tb_address_generator` (widths 3/4/5), golden stream address check |
| Logic 0 / 1 = all-0 / all-1 word | `pattern_generator` | checked at DATA_WIDTH 1, 8, 16, 32 |
| Data comparator, status latch, pass/fail | `data_comparator`, `status_monitor`, `mbist_top` | unit tests + top tests + mutants |
| Fault injection of the 11 models | `fault_injection` | 106 directed cases; exhaustive coverage run; activation vs detection separated |
| Table I definitions | - | **only one-line definitions** (see section 5) |
| 50 MHz MAX 10 results (125.38 mW, 1.36 mW, 4.4 uJ) | - | **not ours** - no synthesis/power run was done |

## 4. Fault coverage of our March mSR+ RTL

Instance = one fault model + parameter variant + victim (+ aggressor). "Detected" requires
that the fault was *activated* (it changed a read, a stored value or a victim cell) **and**
`fail` was reported. The per-model percentages are the same for 8 cells (1,440 instances per power-up state) and
16 cells (5,952); X and all-1 power-up give the same numbers, all-0 moves 64 instances (8-cell
case) between "escaped" and "not excited". The RTL and an independent behavioural March
engine agree on every instance (activation count and detection).

| Model | Detected | Remark |
|---|---|---|
| SAF | 100% | both stuck values |
| TF | 100% | both directions |
| CFid | 100% | A rising/falling x forced value 0/1, aggressor above and below victim |
| CFin | 100% | A rising/falling |
| RDF | 100% | |
| DRDF | 100% | |
| IRF | 100% | |
| CFtr | 100% | all 4 variants |
| CFdrd (standard FFM: victim read while aggressor holds a) | **50%** | detected only when aggressor value = victim value; with opposite values the flip happens in a read that is immediately followed by a write (S2, S5-S9, S12) which overwrites it, in S12's final r0 after which the cell is never read again, or in the pure-read elements (S3, S4, S10, S11), which see uniform data |
| CFwd (standard FFM) | **25%** | only the 1w1 case with aggressor = 1 (S6). 0w0 never occurs in the sequence |
| WDF (standard) | **50%** | only 1w1 (S6); 0w0 never occurs after power-up X |
| CFdrd-P (paper-literal: aggressor *read* disturbs victim) | 100% | |
| CFwd-P (paper-literal: aggressor *write* is copied into victim) | 100% | |

Algorithm comparison with the same fault models (8 cells, detected / instances):

| model | mSR+ | mSR | MATS++ | March C- |
|---|---|---|---|---|
| SAF | 16/16 | 16/16 | 16/16 | 16/16 |
| TF | 16/16 | 16/16 | 16/16 | 16/16 |
| DRDF | 16/16 | 16/16 | 0/16 | 0/16 |
| CFdrd (std) | 112/224 | 112/224 | 0/224 | 0/224 |
| CFwd (std) | 56/224 | 0/224 | 0/224 | 0/224 |
| WDF (std) | 8/16 | 0/16 | 0/16 | 0/16 |
| CFdrd-P | 224/224 | 168/224 | 84/224 | 224/224 |

Full tables: `docs/coverage_report_8cells.txt`, `docs/coverage_report_16cells.txt`.

## 5. Comparison with the paper's claims

Consistent with the paper:
* Algorithm, 22N vs 13N, and its structure (Tables II, III, VII).
* All algorithms detect SAF/TF/IRF fully (Table VIII text).
* DRDF: mSR and mSR+ detect, MATS++ and March C- do not.
* CFdrd: MATS++ and March C- detect nothing (standard model); mSR reaches 50% (paper: 4/8).
* WDF and CFwd: only mSR+ detects any (Table I "typical detection: March mSR+").

**Not reproduced (honest differences):**
* The paper says mSR+ detects CFdrd **8/8** and mSR 4/8. With the standard model mSR+ and mSR
  both reach 4/8-equivalent (50%); with the paper-literal model mSR+ is 100% but mSR is 75%
  and March C- 100% (paper: 0).
* The paper's text says mSR+/mSR fully detect WDF; our standard WDF is 50% for mSR+, 0% for mSR.
* The paper's "100% across 11 models" requires the *paper's* (unpublished) fault
  definitions. With standard definitions 8 of the 11 models are at 100%; with the
  paper-literal CFdrd/CFwd, 10 of 11 (WDF stays at 50%). The paper's WDF ("word-line disturb")
  was not modelled: Table I only says "word-line activation disturbs nearby word lines".
* The paper's own numbers are inconsistent: 32/36 (mSR+) vs 30/36 (mSR) differ by 2 although
  its CFdrd figures alone (8/8 vs 4/8) differ by 4; Table I swaps the usual meaning of CFid/CFin;
  Algorithm 1 (pseudocode) does not match Tables II/III; Table II describes S11 as "verify 0"
  but its command is r1; Table VIII lists no WDF/CFwd detection for mSR+ while the text says WDF is
  fully detected. **Do not claim 32/36 or 100% as our result**; our measured numbers are in section 4.

Claim audit
* May be stated (supported by our simulation): the March mSR+ sequence and 22N operation count
  are implemented and verified; the coverage table in section 4 with its fault-model definitions.
* May be stated only as the paper's: 32/36, 83.33%, 8/8 vs 4/8 CFdrd, 125.38 mW, 1.36 mW, 4.4 uJ,
  area, MAX 10 / 50 MHz results.
* Must not be claimed yet: 100% coverage; any Basys 3 power, timing, resource or hardware result.

## 6. Verification evidence

* `sim/run_regression.sh --full`: 17 of 17 pass (12 unit, 4 top-level width configurations, 1 coverage).
  `--cov4` (16 cells) also passes.
* `sim/run_mutation_check.py`: 22 of 22 mutants killed.
* Verilator 5 lint (`-Wall`, ignoring unused-signal and end-of-file-newline notes) of the RTL is
  clean at 4x32, 3x8 and 5x1 configurations.
* Not done: Vivado xsim run of the new testbenches, synthesis, implementation, hardware.

## 7. Basys 3 / Vivado assessment

* RTL is plain synthesisable SystemVerilog; `sram_model` and `fault_injection` are simulation
  models (verification-only ports, asynchronous read). For hardware the SRAM must be replaced
  with a real memory (distributed RAM supports asynchronous read; Block RAM would need a
  one-cycle read latency and a controller change) and the fault injector removed or kept only as a
  debug feature.
* A board wrapper is still needed: 100 MHz clock (or a divided clock), reset/start buttons or
  switches, pass/fail/done LEDs, `.xdc` constraints.
* Power, timing and utilisation must be measured on our own implementation; the paper's
  Intel MAX 10 numbers do not apply.
* `xvlog` needs no include paths (testbenches are self-contained). The existing `.bat` files and
  `mbist_top_waveform.wcfg` should stay compatible (every signal it names still exists); extra debug signal available: `dut/fault_injection_inst/fault_activated`.

## 8. Next steps

1. (Done) `run_all_tb.bat` was run with Vivado xsim 2025.1: all 12 testbenches PASS, including the exhaustive fault-coverage run.
2. Decide with the supervisor which CFdrd/CFwd/WDF definitions to adopt; ask the authors for the
   exact fault lists behind Table VIII if the 8/8 vs 4/8 comparison must be reproduced.
3. Board wrapper + `.xdc`, synthesis/implementation reports, hardware test.
4. Optionally integrate `fault_logger` (first/last failing address) and `pass_fail_indicator`.
