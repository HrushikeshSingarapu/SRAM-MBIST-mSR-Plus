`timescale 1ns/1ps

//============================================================
// Pattern generator test
// Checks every (March element, operation index) against the
// independent paper reference (reference functions in this file) for two data
// widths, plus inactive/invalid steps.
//============================================================

module tb_pattern_generator;

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

    logic [3:0] march_step;
    logic [1:0] operation_index;

    logic        r8,  w8;
    logic [7:0]  wd8, ex8;
    logic        r32, w32;
    logic [31:0] wd32, ex32;

    pattern_generator #(.DATA_WIDTH(8))  dut8  (
        .march_step(march_step), .operation_index(operation_index),
        .mem_read(r8), .mem_write(w8), .write_data(wd8), .expected_data(ex8));

    pattern_generator #(.DATA_WIDTH(32)) dut32 (
        .march_step(march_step), .operation_index(operation_index),
        .mem_read(r32), .mem_write(w32), .write_data(wd32), .expected_data(ex32));

    int errors = 0;
    int total_ops = 0;
    int s, i, code;
    logic exp_r, exp_w, val;

    initial begin

        for (s = 0; s <= 12; s++) begin
            for (i = 0; i < ref_nops(s); i++) begin

                march_step = s; operation_index = i; #1;

                code  = ref_opcode(s, i);
                exp_r = ref_is_read(code);
                exp_w = !exp_r;
                val   = ref_value(code);
                total_ops++;

                if (r8 !== exp_r || w8 !== exp_w || r32 !== exp_r || w32 !== exp_w) begin
                    $display("ERROR S%0d OP%0d: strobes r8=%b w8=%b r32=%b w32=%b (exp r=%b w=%b)",
                             s, i, r8, w8, r32, w32, exp_r, exp_w);
                    errors++;
                end

                if (exp_r) begin
                    if (ex8 !== {8{val}} || ex32 !== {32{val}}) begin
                        $display("ERROR S%0d OP%0d: expected_data %h / %h, want all-%0d",
                                 s, i, ex8, ex32, val);
                        errors++;
                    end
                end
                else begin
                    if (wd8 !== {8{val}} || wd32 !== {32{val}}) begin
                        $display("ERROR S%0d OP%0d: write_data %h / %h, want all-%0d",
                                 s, i, wd8, wd32, val);
                        errors++;
                    end
                end
            end
        end

        if (total_ops != 22) begin
            $display("ERROR: reference has %0d ops per cell, expected 22", total_ops);
            errors++;
        end

        // Invalid steps 13..15 must not access the memory.
        for (s = 13; s <= 15; s++) begin
            for (i = 0; i < 4; i++) begin
                march_step = s; operation_index = i; #1;
                if (r8 !== 1'b0 || w8 !== 1'b0 || r32 !== 1'b0 || w32 !== 1'b0) begin
                    $display("ERROR: invalid step %0d OP%0d accesses memory", s, i);
                    errors++;
                end
            end
        end

        $display("----------------------------------------");
        if (errors == 0) $display("PATTERN GENERATOR TEST PASSED (%0d operations checked)", total_ops);
        else             $display("PATTERN GENERATOR TEST FAILED: %0d errors", errors);
        $display("----------------------------------------");
        if (errors != 0) $fatal(1, "pattern generator errors");
        $finish;
    end

endmodule
