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

🚧 **In Development**

The repository will be updated as the RTL design, SRAM model,
fault-injection environment, verification infrastructure, and FPGA
implementation are developed.

## Reference

M.-Y. Lin, W.-K. Chiang, and C.-H. Wang,\
"Enhancing Memory BIST With an Optimized RTL-BIST IP Core: A Low-Power,
High-Fault-Coverage Approach,"\
IEEE Transactions on Very Large Scale Integration (VLSI) Systems,
vol. 33, no. 9, pp. 2556--2569, Sep. 2025.
