`timescale 1ns/1ps

module tb_address_generator;
    localparam int ADDR_WIDTH = 4;

    logic clk, rst;
    logic direction_up, restart_direction_up;
    logic cell_complete, address_restart;
    logic [ADDR_WIDTH-1:0] addr;
    logic last_addr;

    address_generator #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
        .clk(clk), .rst(rst),
        .direction_up(direction_up),
        .restart_direction_up(restart_direction_up),
        .cell_complete(cell_complete),
        .address_restart(address_restart),
        .addr(addr), .last_addr(last_addr)
    );

    always #5 clk = ~clk;

    task automatic check(input logic [ADDR_WIDTH-1:0] exp, input string msg);
        if (addr !== exp) begin
            $display("ERROR: %s | expected=%0d got=%0d", msg, exp, addr);
            $fatal;
        end
        $display("PASS: %s | addr=%0d", msg, addr);
    endtask

    initial begin
        clk = 0; rst = 1; direction_up = 1; restart_direction_up = 1;
        cell_complete = 0; address_restart = 0;
        repeat (2) @(posedge clk);
        rst = 0;

        // Reset starts at zero; verify ascending traversal.
        #1 check(0, "reset/ascending start");
        repeat (3) begin
            @(negedge clk); cell_complete = 1;
            @(negedge clk); cell_complete = 0;
        end
        #1 check(3, "ascending traversal");
        if (last_addr !== 0) $fatal(1, "last_addr asserted too early");

        // Ascending restart.
        @(negedge clk); restart_direction_up = 1; address_restart = 1;
        @(negedge clk); address_restart = 0;
        #1 check(0, "ascending restart");

        // Descending restart must go to MAX.
        @(negedge clk); direction_up = 0; restart_direction_up = 0; address_restart = 1;
        @(negedge clk); address_restart = 0;
        #1 check(15, "descending restart");
        if (last_addr !== 0) $fatal(1, "descending last_addr incorrect");

        repeat (3) begin
            @(negedge clk); cell_complete = 1;
            @(negedge clk); cell_complete = 0;
        end
        #1 check(12, "descending traversal");

        $display("----------------------------------------");
        $display("ADDRESS GENERATOR TEST PASSED");
        $display("----------------------------------------");
        $finish;
    end
endmodule
