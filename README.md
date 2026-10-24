# Design and Verification of an SRAM MBIST IP Core Using the Optimized March mSR+ Algorithm

An RTL-based SRAM Memory Built-In Self-Test (MBIST) IP core implementing
the optimized March mSR+ algorithm for systematic SRAM fault detection.

## Overview

This project focuses on the design and verification of an SRAM MBIST IP
core based on the RTL-BIST architecture described in the project
reference paper.

The MBIST controller applies the optimized March mSR+ test sequence to
an SRAM memory model using controlled read/write operations and
bidirectional address traversal. Representative SRAM faults are injected
into the memory model and their detection is verified through RTL
simulation.

The design is also intended for synthesis and implementation on a
Digilent Basys 3 FPGA using Xilinx Vivado.

## Key Features

-   SRAM MBIST controller based on March mSR+
-   Ascending and descending address traversal
-   Read and write test operations
-   Read-after-read operations
-   Interleaved read/write operations
-   SRAM fault-injection models
-   Fault detection and PASS/FAIL status
-   RTL-based functional verification
-   Vivado synthesis and FPGA implementation

## Project Architecture

``` text
MBIST Controller (March mSR+ FSM)
            |
     Address Generator
            |
 Pattern / Read-Write Control
            |
       SRAM Memory Model
            |
       Data Comparator
            |
    Fault Detection / Status
            |
         PASS / FAIL

Fault Injection -> SRAM Memory Model
```

## March mSR+ Algorithm

The project implements the optimized March mSR+ algorithm described in
the base paper.

The test sequence uses:

-   Ascending and descending address traversal
-   `w0` and `w1` write operations
-   `r0` and `r1` read operations
-   Read-after-read operations
-   Interleaved read/write operations
-   Fault-oriented test sequences

The project proposal reports 22N operations for March mSR+ compared with
13N for March mSR, as reported in the base paper.

## Verification

Representative SRAM faults will be injected into the memory model and
the MBIST controller's ability to detect them will be verified through
RTL simulation.

The verification flow includes:

1.  SRAM memory modeling
2.  Fault injection
3.  March mSR+ execution
4.  Expected-versus-observed data comparison
5.  Fault detection
6.  PASS/FAIL status generation
7.  Fault coverage analysis

## Implementation

### Hardware

-   Digilent Basys 3 FPGA
-   SRAM memory model
-   Host PC

### Software / EDA

-   Verilog / SystemVerilog
-   Xilinx Vivado
-   Vivado Simulator
-   Vivado Synthesis and Implementation

### Implementation Flow

``` text
RTL Design
    ↓
Vivado Simulation
    ↓
Fault Injection
    ↓
Functional Verification
    ↓
Vivado Synthesis
    ↓
Basys 3 Implementation
    ↓
Hardware Validation
```

## Objectives

-   Design an SRAM MBIST IP core based on the RTL-BIST architecture
-   Implement the optimized March mSR+ algorithm
-   Develop SRAM fault-injection models
-   Verify fault detection through RTL simulation
-   Compare March mSR and March mSR+ in terms of fault coverage and test
    complexity
-   Synthesize and implement the MBIST IP on the Basys 3 FPGA
-   Validate the implemented design through functional and hardware
    testing

## Team

**Hrushikesh Singarapu**\
**Mohammad Fardin**\
**Y Sai Ruthwik**

**Supervisor:** A. Srinivas\
Department of Electronics and Communication Engineering\
Vasavi College of Engineering

## Project Status

**RTL and simulation-based verification: in place and regression-clean (simulation only; see the report for coverage limits).**
Not yet done: Basys 3 wrapper/constraints, synthesis, implementation, hardware validation.

### Verification at a glance

* The March mSR+ sequence (S0-S12, 22 operations per cell) is checked against an independent
  transcription of the paper's Tables II/III (`tb/tb_mbist_top.sv`, `tb/tb_bist_controller.sv`,
  `tb/tb_pattern_generator.sv`).
* Every fault test separates *activation* (`fault_activated`) from *detection* (`fail`).
* `tb/tb_fault_coverage.sv` runs every fault model, variant, victim and aggressor/victim pair and
  cross-checks the RTL against an independent behavioural March engine.
* 22 injected RTL bugs are all caught by the testbenches (`sim/run_mutation_check.py`).
* Fault-coverage results, how they compare with the paper, and the claim audit are in
  `docs/VERIFICATION_REPORT.md`; the file-by-file change list is `docs/CHANGES.md`.

### Run

```text
sim/run_regression.sh            # unit + top-level tests (Icarus Verilog, ~2 s)
sim/run_regression.sh --full     # + exhaustive fault coverage (~1 min)
python3 sim/run_mutation_check.py
run_all_tb.bat                  # all 12 testbenches with Vivado xsim (Windows); prints one PASS/FAIL line each
```

### Interface semantics (`mbist_top`)

`start` pulse while idle -> `busy` high -> `done` rises **together with** `pass`/`fail` and stays
high until the next start. A `start` while busy is ignored. `fault_*` inputs and
`fault_variant` configure the verification-only fault injector (`fault_enable = 0` for a
fault-free memory).

> The paper's power/area/timing/coverage figures belong to the paper's own MAX 10 implementation.
> They are not results of this project.

## Reference

M.-Y. Lin, W.-K. Chiang, and C.-H. Wang,\
"Enhancing Memory BIST With an Optimized RTL-BIST IP Core: A Low-Power,
High-Fault-Coverage Approach,"\
IEEE Transactions on Very Large Scale Integration (VLSI) Systems,
vol. 33, no. 9, pp. 2556--2569, Sep. 2025.
