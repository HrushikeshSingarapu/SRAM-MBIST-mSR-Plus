`timescale 1ns/1ps

//============================================================
// BIST controller test
//
// The controller is driven with a small behavioural address
// model (N addresses) and every output is compared, cycle by
// cycle, with the independent paper reference (reference functions in this file):
//   march_step, operation_index, direction, restart direction,
//   cell_complete, step_complete, address_restart, busy, done.
// A second start (no reset) verifies re-run behaviour.
//============================================================

module tb_bist_controller;

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

    localparam int N = 4;   // modelled number of addresses

    logic clk, rst, start;
    logic last_addr;
    logic busy, done, direction_up, restart_direction_up;
    logic cell_complete, step_complete, address_restart;
    logic [3:0] march_step;
    logic [1:0] operation_index;

    bist_controller dut (
        .clk(clk), .rst(rst), .start(start), .last_addr(last_addr),
        .busy(busy), .done(done), .direction_up(direction_up),
        .restart_direction_up(restart_direction_up),
        .cell_complete(cell_complete), .step_complete(step_complete),
        .address_restart(address_restart), .march_step(march_step),
        .operation_index(operation_index)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Behavioural address counter: 0..N-1 within an element
    int a_cnt;
    assign last_addr = (a_cnt == N-1);

    always @(posedge clk or posedge rst) begin
        if (rst)                a_cnt <= 0;
        else if (step_complete) a_cnt <= 0;
        else if (cell_complete) a_cnt <= a_cnt + 1;
    end

    int errors = 0;
    int cycles = 0;

    task automatic check_cycle(input int s, input int a, input int i);
        bit exp_cell, exp_step, exp_restart_up;
        begin
            exp_cell    = (i == ref_nops(s) - 1);
            exp_step    = exp_cell && (a == N-1);
            exp_restart_up = (s == 12) ? 1'b1 : ref_up(s + 1);

            if (busy !== 1'b1 || done !== 1'b0) begin
                $display("ERROR S%0d a%0d OP%0d: busy=%b done=%b", s, a, i, busy, done);
                errors++;
            end
            if (march_step !== s || operation_index !== i) begin
                $display("ERROR: expected S%0d OP%0d got S%0d OP%0d (addr idx %0d)",
                         s, i, march_step, operation_index, a);
                errors++;
            end
            if (direction_up !== ref_up(s)) begin
                $display("ERROR S%0d: direction_up=%b expected %b", s, direction_up, ref_up(s));
                errors++;
            end
            if (restart_direction_up !== exp_restart_up) begin
                $display("ERROR S%0d: restart_direction_up=%b expected %b",
                         s, restart_direction_up, exp_restart_up);
                errors++;
            end
            if (cell_complete !== exp_cell) begin
                $display("ERROR S%0d a%0d OP%0d: cell_complete=%b expected %b",
                         s, a, i, cell_complete, exp_cell);
                errors++;
            end
            if (step_complete !== exp_step || address_restart !== exp_step) begin
                $display("ERROR S%0d a%0d OP%0d: step_complete=%b address_restart=%b expected %b",
                         s, a, i, step_complete, address_restart, exp_step);
                errors++;
            end
            cycles++;
        end
    endtask

    task automatic run_and_check(input string name);
        int s, a, i;
        bit first;
        begin
            cycles = 0;
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            #1;
            first = 1;
            for (s = 0; s <= 12; s++)
                for (a = 0; a < N; a++)
                    for (i = 0; i < ref_nops(s); i++) begin
                        if (!first) begin @(negedge clk); #1; end
                        first = 0;
                        check_cycle(s, a, i);
                    end

            // DONE cycle
            @(negedge clk); #1;
            if (done !== 1'b1 || busy !== 1'b0) begin
                $display("ERROR (%s): DONE cycle busy=%b done=%b", name, busy, done);
                errors++;
            end
            if (cell_complete !== 1'b0 || step_complete !== 1'b0 || address_restart !== 1'b0) begin
                $display("ERROR (%s): strobes active in DONE", name);
                errors++;
            end

            // back to IDLE
            @(negedge clk); #1;
            if (done !== 1'b0 || busy !== 1'b0) begin
                $display("ERROR (%s): IDLE busy=%b done=%b", name, busy, done);
                errors++;
            end

            if (cycles != 22 * N) begin
                $display("ERROR (%s): %0d operation cycles, expected %0d", name, cycles, 22 * N);
                errors++;
            end
            $display("run '%s': %0d operation cycles checked", name, cycles);
        end
    endtask

    initial begin
        rst = 1; start = 0;
        repeat (2) @(posedge clk);
        #1 rst = 0;

        // idle must be quiet
        @(negedge clk); #1;
        if (busy !== 1'b0 || done !== 1'b0 || cell_complete !== 1'b0) begin
            $display("ERROR: controller not quiet in IDLE"); errors++;
        end

        run_and_check("first run");
        run_and_check("second run (no reset)");

        // reset in the middle of a run returns to IDLE
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;
        repeat (7) @(negedge clk);
        rst = 1; #1;
        @(negedge clk); #1;
        if (busy !== 1'b0 || done !== 1'b0) begin
            $display("ERROR: reset did not return controller to IDLE"); errors++;
        end
        rst = 0;
        run_and_check("run after mid-test reset");

        $display("----------------------------------------");
        if (errors == 0) $display("BIST CONTROLLER TEST PASSED");
        else             $display("BIST CONTROLLER TEST FAILED: %0d errors", errors);
        $display("----------------------------------------");
        if (errors != 0) $fatal(1, "bist controller errors");
        $finish;
    end

endmodule
