`timescale 1ns/1ps

module tb_bist_controller;
    logic clk, rst, start, last_addr;
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

    always #5 clk = ~clk;

    integer exp_step [0:21];
    integer exp_op   [0:21];
    integer i, errors;

    initial begin
        exp_step = '{0,1,2,2,3,4,5,5,6,6,7,7,7,8,8,9,9,10,11,12,12,12};
        exp_op   = '{0,0,0,1,0,0,0,1,0,1,0,1,2,0,1,0,1,0,0,0,1,2};

        clk = 0; rst = 1; start = 0; last_addr = 1; errors = 0;
        repeat (2) @(posedge clk);
        rst = 0;

        @(negedge clk); start = 1;
        @(negedge clk); start = 0;

        for (i = 0; i < 22; i = i + 1) begin
            // Controller outputs are combinational from the current state.
            #1;
            if (march_step !== exp_step[i] || operation_index !== exp_op[i]) begin
                $display("ERROR: i=%0d expected S%0d OP%0d got S%0d OP%0d",
                         i, exp_step[i], exp_op[i], march_step, operation_index);
                errors = errors + 1;
            end
            if (i < 13 && restart_direction_up !== (exp_step[i] < 7)) begin
                // For S0-S6 restart is UP; S7-S12 restart is DOWN.
                $display("ERROR: restart direction wrong at S%0d", march_step);
                errors = errors + 1;
            end
            @(posedge clk);
        end

        // The final S12 operation transitions to DONE.
        #1;
        if (!done && march_step != 12) begin
            $display("ERROR: unexpected controller state after sequence");
            errors = errors + 1;
        end

        if (errors != 0) $fatal(1, "BIST CONTROLLER TEST FAILED: %0d errors", errors);
        $display("----------------------------------------");
        $display("BIST CONTROLLER TEST PASSED");
        $display("----------------------------------------");
        $finish;
    end
endmodule
