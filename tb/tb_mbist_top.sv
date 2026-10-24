`timescale 1ns/1ps

//============================================================
// MBIST TOP - self-checking integration testbench
//
// Every test checks, against the independent paper reference
// (reference functions in this file), that
//   * the memory operations issued to the SRAM are exactly the
//     22 operations per cell of March mSR+ in the right order,
//     at the right addresses, with the right data
//     (13 March elements, S0..S12, ascending S0-S7 / descending
//     S8-S12, descending traversal starts at the MAX address),
//   * no SRAM access happens while the BIST is idle/finished,
//   * busy is continuous, done rises together with valid one-hot
//     pass/fail, and pass/fail stay low until done,
//   * for fault tests, the intended fault was really ACTIVATED
//     (fault_activated) before a detection is accepted, and a
//     fail without activation is an error.
//
// The simulation exits with an error if any check fails.
//============================================================

module tb_mbist_top #(
    parameter int ADDR_WIDTH = 3,
    parameter int DATA_WIDTH = 8
);

    //--------------------------------------------------------
    // Independent March mSR+ reference (paper Table II/III),
    // NOT derived from the RTL. Op codes: 0=r0 1=r1 2=w0 3=w1
    //--------------------------------------------------------
    function automatic int ref_nops(input int s);
        case (s)
            0, 1, 3, 4, 10, 11 : ref_nops = 1;
            2, 5, 6, 8, 9      : ref_nops = 2;
            7, 12              : ref_nops = 3;
            default            : ref_nops = 0;
        endcase
    endfunction

    function automatic int ref_opcode(input int s, input int i);
        case (s)
            0:  ref_opcode = 2;                                   // w0
            1:  ref_opcode = 3;                                   // w1
            2:  ref_opcode = (i == 0) ? 1 : 2;                    // r1,w0
            3:  ref_opcode = 0;                                   // r0
            4:  ref_opcode = 0;                                   // r0
            5:  ref_opcode = (i == 0) ? 0 : 3;                    // r0,w1
            6:  ref_opcode = (i == 0) ? 1 : 3;                    // r1,w1
            7:  ref_opcode = (i == 0) ? 1 : ((i == 1) ? 2 : 3);   // r1,w0,w1
            8:  ref_opcode = (i == 0) ? 1 : 2;                    // r1,w0
            9:  ref_opcode = (i == 0) ? 0 : 3;                    // r0,w1
            10: ref_opcode = 1;                                   // r1
            11: ref_opcode = 1;                                   // r1
            12: ref_opcode = (i == 0) ? 1 : ((i == 1) ? 2 : 0);   // r1,w0,r0
            default: ref_opcode = -1;
        endcase
    endfunction

    // S0..S7 ascending, S8..S12 descending
    function automatic bit ref_up(input int s);
        ref_up = (s <= 7);
    endfunction

    function automatic bit ref_is_read(input int code);
        ref_is_read = (code == 0) || (code == 1);
    endfunction

    // data value of the operation: 0 for r0/w0, 1 for r1/w1
    function automatic bit ref_value(input int code);
        ref_value = (code == 1) || (code == 3);
    endfunction

    localparam int N      = 1 << ADDR_WIDTH;
    localparam int TOTAL  = 22 * N;

    //--------------------------------------------------------
    // DUT signals
    //--------------------------------------------------------

    logic clk = 0;
    logic rst, start;

    logic                  fault_enable;
    logic [3:0]            fault_type;
    logic [ADDR_WIDTH-1:0] fault_address, aggressor_address;
    logic                  stuck_at_value, fault_variant;

    logic busy, done, pass, fail;
    logic [ADDR_WIDTH-1:0] current_address;
    logic [3:0]            march_step;
    logic [1:0]            operation_index;
    logic                  direction_up;

    localparam logic [3:0] FAULT_SAF = 0, FAULT_TF = 1, FAULT_CFID = 2, FAULT_CFDRD = 3,
                           FAULT_CFIN = 4, FAULT_RDF = 5, FAULT_DRDF = 6, FAULT_IRF = 7,
                           FAULT_CFTR = 8, FAULT_CFWD = 9, FAULT_WDF = 10,
                           FAULT_CFDRD_P = 11, FAULT_CFWD_P = 12;

    mbist_top #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .rst(rst), .start(start),
        .fault_enable(fault_enable), .fault_type(fault_type),
        .fault_address(fault_address), .aggressor_address(aggressor_address),
        .stuck_at_value(stuck_at_value), .fault_variant(fault_variant),
        .busy(busy), .done(done), .pass(pass), .fail(fail),
        .current_address(current_address), .march_step(march_step),
        .operation_index(operation_index), .direction_up(direction_up)
    );

    always #5 clk = ~clk;

    //--------------------------------------------------------
    // Golden operation stream (from the paper reference)
    //--------------------------------------------------------

    bit                     g_read [0:TOTAL-1];
    bit                     g_val  [0:TOTAL-1];
    int                     g_addr [0:TOTAL-1];
    int                     g_step [0:TOTAL-1];

    task automatic build_golden;
        int s, i, k, idx, a, code;
        begin
            idx = 0;
            for (s = 0; s <= 12; s++)
                for (k = 0; k < N; k++) begin
                    a = ref_up(s) ? k : (N - 1 - k);
                    for (i = 0; i < ref_nops(s); i++) begin
                        code        = ref_opcode(s, i);
                        g_read[idx] = ref_is_read(code);
                        g_val[idx]  = ref_value(code);
                        g_addr[idx] = a;
                        g_step[idx] = s;
                        idx++;
                    end
                end
            if (idx != TOTAL) begin
                $display("TB INTERNAL ERROR: golden stream has %0d ops, expected %0d", idx, TOTAL);
                $fatal(1, "bad golden stream");
            end
        end
    endtask

    //--------------------------------------------------------
    // Monitors
    //--------------------------------------------------------

    int  errors = 0;

    // per-run
    bit  mon_on;
    int  op_idx;
    int  seq_errors;
    int  act_cnt, mm_cnt;
    int  first_mm_step, first_mm_addr;
    int  gap_errors;
    bit  run_active;

    // always
    int  idle_access;

    always @(posedge clk) begin

        // SRAM must never be accessed while the BIST is not running
        if (!rst && (dut.mem_read === 1'b1 || dut.mem_write === 1'b1) &&
            dut.ctrl_busy !== 1'b1)
            idle_access++;

        if (mon_on) begin

            if (dut.mem_read === 1'b1 || dut.mem_write === 1'b1) begin

                if (op_idx >= TOTAL) begin
                    seq_errors++;
                    if (seq_errors <= 5) $display("ERROR: more than %0d memory operations", TOTAL);
                end
                else begin
                    if ((dut.mem_read === 1'b1) !== g_read[op_idx] ||
                        (dut.mem_write === 1'b1) === (dut.mem_read === 1'b1)) begin
                        seq_errors++;
                        if (seq_errors <= 5)
                            $display("ERROR op %0d (S%0d): read/write kind wrong (rd=%b wr=%b, expected %s)",
                                     op_idx, g_step[op_idx], dut.mem_read, dut.mem_write,
                                     g_read[op_idx] ? "read" : "write");
                    end
                    if (current_address !== g_addr[op_idx][ADDR_WIDTH-1:0]) begin
                        seq_errors++;
                        if (seq_errors <= 5)
                            $display("ERROR op %0d (S%0d): address %0d expected %0d",
                                     op_idx, g_step[op_idx], current_address, g_addr[op_idx]);
                    end
                    if (march_step !== g_step[op_idx]) begin
                        seq_errors++;
                        if (seq_errors <= 5)
                            $display("ERROR op %0d: march_step S%0d expected S%0d",
                                     op_idx, march_step, g_step[op_idx]);
                    end
                    if (g_read[op_idx]) begin
                        if (dut.expected_data !== {DATA_WIDTH{g_val[op_idx]}}) begin
                            seq_errors++;
                            if (seq_errors <= 5)
                                $display("ERROR op %0d (S%0d): expected_data %h, want all-%0d",
                                         op_idx, g_step[op_idx], dut.expected_data, g_val[op_idx]);
                        end
                    end
                    else begin
                        if (dut.write_data !== {DATA_WIDTH{g_val[op_idx]}}) begin
                            seq_errors++;
                            if (seq_errors <= 5)
                                $display("ERROR op %0d (S%0d): write_data %h, want all-%0d",
                                         op_idx, g_step[op_idx], dut.write_data, g_val[op_idx]);
                        end
                    end
                end
                op_idx++;
            end

            if (dut.fault_activated === 1'b1) act_cnt++;

            if (dut.mismatch === 1'b1) begin
                if (mm_cnt == 0) begin
                    first_mm_step = march_step;
                    first_mm_addr = current_address;
                end
                mm_cnt++;
            end

        end
    end

    // busy must be continuous while a run is in progress; pass/fail low until done
    always @(negedge clk) begin
        if (run_active && !done) begin
            if (busy !== 1'b1) gap_errors++;
            if (pass !== 1'b0 || fail !== 1'b0) gap_errors++;
        end
    end

    //--------------------------------------------------------
    // Test infrastructure
    //--------------------------------------------------------

    // Power-up: the SRAM content is unknown (X). The March algorithm
    // must initialise every cell itself (S0), so results never depend
    // on leftover data from an earlier test.
    task automatic power_up_memory;
        int k;
        begin
            for (k = 0; k < N; k++) dut.sram_model_inst.mem[k] = 'x;
        end
    endtask

    task automatic apply_reset;
        begin
            power_up_memory;
            rst = 1; start = 0;
            @(negedge clk); @(negedge clk);
            rst = 0;
            @(negedge clk);
        end
    endtask

    task automatic set_fault(input bit en, input logic [3:0] ft, input int fv, input int fvar,
                             input int v, input int a);
        begin
            fault_enable      = en;
            fault_type        = ft;
            stuck_at_value    = fv;
            fault_variant     = fvar;
            fault_address     = v;
            aggressor_address = a;
        end
    endtask

    // Run one complete MBIST (start pulse -> done). Optionally pulse start
    // again in the middle of the test (must be ignored).
    task automatic run_bist(input bit spurious_start);
        int timeout, cyc;
        begin
            op_idx = 0; seq_errors = 0; act_cnt = 0; mm_cnt = 0;
            first_mm_step = -1; first_mm_addr = -1; gap_errors = 0;
            mon_on = 1;

            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            run_active = 1;

            timeout = TOTAL + 100;
            cyc = 0;
            while (!done && timeout > 0) begin
                @(negedge clk);
                timeout--;
                cyc++;
                if (spurious_start && cyc == (TOTAL - 3)) begin   // after the last mismatch, before done
                    start = 1;
                    @(negedge clk);
                    start = 0;
                end
            end

            if (!done) begin
                $display("ERROR: timeout waiting for done"); errors++;
            end

            // done rises together with valid pass/fail
            if ((pass ^ fail) !== 1'b1) begin
                $display("ERROR: done=1 but pass=%b fail=%b (not one-hot)", pass, fail); errors++;
            end
            if (busy !== 1'b0) begin
                $display("ERROR: busy still high when done rises"); errors++;
            end

            run_active = 0;
            mon_on = 0;

            if (seq_errors != 0) begin
                $display("ERROR: %0d March-sequence violations", seq_errors); errors++;
            end
            if (op_idx != TOTAL) begin
                $display("ERROR: %0d memory operations executed, expected %0d (22 per cell x %0d cells)",
                         op_idx, TOTAL, N); errors++;
            end
            if (gap_errors != 0) begin
                $display("ERROR: busy gap / early pass-fail (%0d)", gap_errors); errors++;
            end
        end
    endtask

    task automatic check_result(input string name, input bit exp_fail, input bit exp_activation);
        begin
            if (exp_fail) begin
                if (!(fail === 1'b1 && pass === 1'b0)) begin
                    $display("FAIL: %s : expected FAIL result, got pass=%b fail=%b", name, pass, fail); errors++;
                end
            end
            else begin
                if (!(pass === 1'b1 && fail === 1'b0)) begin
                    $display("FAIL: %s : expected PASS result, got pass=%b fail=%b", name, pass, fail); errors++;
                end
            end

            if (exp_activation && act_cnt == 0) begin
                $display("FAIL: %s : fault was never activated by the March sequence", name); errors++;
            end
            if (!exp_activation && act_cnt != 0) begin
                $display("FAIL: %s : unexpected fault activation (%0d)", name, act_cnt); errors++;
            end

            // detection must be caused by an activated fault + a real mismatch
            if (fail === 1'b1 && (mm_cnt == 0 || act_cnt == 0)) begin
                $display("FAIL: %s : fail without mismatch/activation (mm=%0d act=%0d)", name, mm_cnt, act_cnt);
                errors++;
            end
            if (pass === 1'b1 && mm_cnt != 0) begin
                $display("FAIL: %s : pass although comparator saw %0d mismatches", name, mm_cnt); errors++;
            end
        end
    endtask

    task automatic fault_test(input string name, input logic [3:0] ft, input int fv, input int fvar,
                              input int v, input int a, input bit exp_fail, input bit exp_act);
        int e0;
        begin
            e0 = errors;
            apply_reset;
            set_fault(1, ft, fv, fvar, v, a);
            run_bist(0);
            check_result(name, exp_fail, exp_act);
            if (errors == e0)
                $display("PASS: %-34s activations=%0d mismatches=%0d first mismatch S%0d @addr %0d -> %s",
                         name, act_cnt, mm_cnt, first_mm_step, first_mm_addr,
                         fail ? "FAIL reported" : "PASS reported");
        end
    endtask

    //--------------------------------------------------------
    // Main sequence
    //--------------------------------------------------------

    int e0;

    initial begin

        build_golden;

        rst = 1; start = 0; mon_on = 0; run_active = 0;
        idle_access = 0; op_idx = 0; seq_errors = 0; act_cnt = 0; mm_cnt = 0; gap_errors = 0;
        set_fault(0, 0, 0, 0, 0, 0);

        //----------------------------------------------------
        // 1. No fault
        //----------------------------------------------------
        $display("\n=== TEST 1: no fault ===");
        e0 = errors;
        apply_reset;
        // idle for a while: nothing must be written
        repeat (20) @(negedge clk);
        run_bist(0);
        check_result("no fault", 0, 0);
        if (done !== 1'b1) begin $display("FAIL: done not high"); errors++; end
        if (errors == e0) $display("PASS: no-fault MBIST: %0d ops, pass, done", op_idx);

        // done/pass stay high until the next start
        repeat (10) @(negedge clk);
        if (!(done === 1'b1 && pass === 1'b1 && fail === 1'b0 && busy === 1'b0)) begin
            $display("FAIL: done/pass not held after completion"); errors++;
        end

        //----------------------------------------------------
        // 2. Re-run without reset (restart address = 0)
        //----------------------------------------------------
        $display("\n=== TEST 2: second run without reset ===");
        e0 = errors;
        run_bist(0);
        check_result("re-run without reset", 0, 0);
        if (errors == e0) $display("PASS: re-run: %0d ops, pass", op_idx);

        //----------------------------------------------------
        // 3. Fault disabled but fault configured
        //----------------------------------------------------
        $display("\n=== TEST 3: fault configured but disabled ===");
        e0 = errors;
        apply_reset;
        set_fault(0, FAULT_SAF, 0, 0, 3, 2);
        run_bist(0);
        check_result("fault_enable = 0", 0, 0);
        if (errors == e0) $display("PASS: disabled fault does not affect the test");

        //----------------------------------------------------
        // 4. One detected instance of every fault model
        //    (activation AND detection are both required)
        //----------------------------------------------------
        $display("\n=== TEST 4: fault models (activation + detection) ===");
        //          name                         type            fv fvar V  A  fail act
        fault_test("SAF (stuck-at-0)",           FAULT_SAF,      0, 0,  3, 0, 1, 1);
        fault_test("SAF (stuck-at-1)",           FAULT_SAF,      1, 0,  3, 0, 1, 1);
        fault_test("TF (0->1 fails)",            FAULT_TF,       0, 0,  3, 0, 1, 1);
        fault_test("TF (1->0 fails)",            FAULT_TF,       1, 0,  3, 0, 1, 1);
        fault_test("CFid (A up forces V=1)",     FAULT_CFID,     1, 0,  3, 2, 1, 1);
        fault_test("CFid (A down forces V=0)",   FAULT_CFID,     0, 1,  3, 5, 1, 1);
        fault_test("CFdrd (std, a=0,x=0)",       FAULT_CFDRD,    0, 0,  3, 2, 1, 1);
        fault_test("CFdrd (std, a=1,x=1)",       FAULT_CFDRD,    1, 1,  3, 5, 1, 1);
        fault_test("CFin (A up inverts V)",      FAULT_CFIN,     0, 0,  3, 2, 1, 1);
        fault_test("CFin (A down inverts V)",    FAULT_CFIN,     0, 1,  3, 5, 1, 1);
        fault_test("RDF (cell holds 0)",         FAULT_RDF,      0, 0,  3, 0, 1, 1);
        fault_test("RDF (cell holds 1)",         FAULT_RDF,      1, 0,  3, 0, 1, 1);
        fault_test("DRDF (cell holds 0)",        FAULT_DRDF,     0, 0,  3, 0, 1, 1);
        fault_test("DRDF (cell holds 1)",        FAULT_DRDF,     1, 0,  3, 0, 1, 1);
        fault_test("IRF (cell holds 0)",         FAULT_IRF,      0, 0,  3, 0, 1, 1);
        fault_test("IRF (cell holds 1)",         FAULT_IRF,      1, 0,  3, 0, 1, 1);
        fault_test("CFtr (A=0 blocks V up)",     FAULT_CFTR,     0, 0,  3, 2, 1, 1);
        fault_test("CFtr (A=1 blocks V down)",   FAULT_CFTR,     1, 1,  3, 5, 1, 1);
        fault_test("CFwd (std, A=1, x=1)",       FAULT_CFWD,     1, 1,  3, 2, 1, 1);
        fault_test("WDF (1w1 flips)",            FAULT_WDF,      1, 0,  3, 0, 1, 1);
        fault_test("CFdrd-P (A read disturbs V)", FAULT_CFDRD_P, 0, 0,  3, 2, 1, 1);
        fault_test("CFwd-P (A write copies to V)", FAULT_CFWD_P, 0, 1,  3, 2, 1, 1);

        //----------------------------------------------------
        // 5. Faults that the March mSR+ sequence does not detect.
        //    These document algorithm limits (see report):
        //    - NOT EXCITED : the sequence never creates the trigger
        //      condition (with an unknown power-up state), so the correct
        //      result is PASS.
        //    - ESCAPED     : the fault is activated but its effect is
        //      overwritten before it is read, so the result is PASS.
        //    A pass here is correct behaviour of the MBIST and also
        //    proves that fail is not raised merely because a fault is
        //    enabled.
        //----------------------------------------------------
        $display("\n=== TEST 5: faults outside March mSR+ reach (pass is correct) ===");
        fault_test("WDF (0w0 never written)  [not excited]", FAULT_WDF,  0, 0, 3, 0, 0, 0);
        fault_test("CFwd std a=0,x=0         [not excited]", FAULT_CFWD, 0, 0, 3, 2, 0, 0);
        fault_test("CFdrd std a=0,x=1        [escaped]",     FAULT_CFDRD, 1, 0, 3, 2, 0, 1);

        //----------------------------------------------------
        // 6. Spurious start during a running test is ignored
        //    (must not clear a latched mismatch)
        //----------------------------------------------------
        $display("\n=== TEST 6: spurious start during a test ===");
        e0 = errors;
        apply_reset;
        set_fault(1, FAULT_SAF, 0, 0, 3, 0);
        run_bist(1);
        check_result("SAF with spurious start", 1, 1);
        if (errors == e0) $display("PASS: spurious start ignored, SAF still reported");

        e0 = errors;
        apply_reset;
        set_fault(0, 0, 0, 0, 0, 0);
        run_bist(1);
        check_result("no fault with spurious start", 0, 0);
        if (errors == e0) $display("PASS: spurious start does not disturb a good test");

        //----------------------------------------------------
        // 7. Faulty run followed by a fault-free run (no reset):
        //    status must be cleared by the new start
        //----------------------------------------------------
        $display("\n=== TEST 7: fail -> clean re-run without reset ===");
        e0 = errors;
        apply_reset;
        set_fault(1, FAULT_SAF, 1, 0, 5, 0);
        run_bist(0);
        check_result("faulty run", 1, 1);
        set_fault(0, 0, 0, 0, 0, 0);
        run_bist(0);
        check_result("clean run after faulty run", 0, 0);
        if (errors == e0) $display("PASS: fail status cleared by a new start");

        //----------------------------------------------------
        // 8. Reset in the middle of a test
        //----------------------------------------------------
        $display("\n=== TEST 8: reset during a test ===");
        e0 = errors;
        apply_reset;
        set_fault(0, 0, 0, 0, 0, 0);
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;
        repeat (TOTAL / 2) @(negedge clk);
        rst = 1;
        @(negedge clk); #1;
        if (busy !== 1'b0 || done !== 1'b0 || pass !== 1'b0 || fail !== 1'b0) begin
            $display("FAIL: outputs not cleared by reset"); errors++;
        end
        rst = 0;
        @(negedge clk);
        run_bist(0);
        check_result("run after mid-test reset", 0, 0);
        if (errors == e0) $display("PASS: reset aborts the test and a new run is clean");

        //----------------------------------------------------
        // final
        //----------------------------------------------------
        if (idle_access != 0) begin
            $display("FAIL: %0d SRAM accesses while the BIST was idle/finished", idle_access);
            errors++;
        end
        else $display("\nPASS: no SRAM access while the BIST was idle or finished");

        $display("\n======================================");
        if (errors == 0) $display("MBIST TOP INTEGRATION TEST PASSED (ADDR_WIDTH=%0d, DATA_WIDTH=%0d)", ADDR_WIDTH, DATA_WIDTH);
        else             $display("MBIST TOP INTEGRATION TEST FAILED: %0d errors", errors);
        $display("======================================");
        if (errors != 0) $fatal(1, "mbist_top integration errors");
        $finish;
    end

endmodule
