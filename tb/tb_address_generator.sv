`timescale 1ns/1ps

//============================================================
// Address generator test (parameterised width; run with
// -P tb_address_generator.ADDR_WIDTH=3/4/5 ...)
//
// Checks: reset address, full ascending sweep (no skip, no
// repeat, no out-of-range), last_addr only at the last address,
// ascending restart to 0, descending restart to MAX, full
// descending sweep, and that the address holds at the end of a
// sweep if cell_complete is (wrongly) asserted again.
//============================================================

module tb_address_generator #(
    parameter int ADDR_WIDTH = 4
);
    localparam int DEPTH = 1 << ADDR_WIDTH;

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

    initial clk = 0;
    always #5 clk = ~clk;

    int errors = 0;

    task automatic expect_addr(input int exp, input string msg);
        begin
            if (addr !== exp[ADDR_WIDTH-1:0]) begin
                $display("ERROR: %s | expected=%0d got=%0d", msg, exp, addr);
                errors++;
            end
        end
    endtask

    task automatic step_cell;
        begin
            @(negedge clk); cell_complete = 1;
            @(negedge clk); cell_complete = 0;
            #1;
        end
    endtask

    task automatic restart(input bit up);
        begin
            @(negedge clk); restart_direction_up = up; address_restart = 1;
            @(negedge clk); address_restart = 0;
            #1;
        end
    endtask

    int k;

    initial begin
        rst = 1; direction_up = 1; restart_direction_up = 1;
        cell_complete = 0; address_restart = 0;
        repeat (2) @(posedge clk);
        #1 rst = 0;

        expect_addr(0, "reset address");

        // ---- full ascending sweep ----
        direction_up = 1;
        for (k = 0; k < DEPTH; k++) begin
            expect_addr(k, "ascending sweep");
            if (last_addr !== (k == DEPTH-1)) begin
                $display("ERROR: ascending last_addr=%b at addr %0d", last_addr, addr);
                errors++;
            end
            if (k != DEPTH-1) step_cell;
        end

        // extra cell_complete at the last address must not wrap
        step_cell;
        expect_addr(DEPTH-1, "ascending: hold at last address");

        // ---- ascending restart ----
        restart(1);
        expect_addr(0, "ascending restart to 0");

        // ---- descending restart + full descending sweep ----
        direction_up = 0;
        restart(0);
        for (k = DEPTH-1; k >= 0; k--) begin
            expect_addr(k, "descending sweep");
            if (last_addr !== (k == 0)) begin
                $display("ERROR: descending last_addr=%b at addr %0d", last_addr, addr);
                errors++;
            end
            if (k != 0) step_cell;
        end

        step_cell;
        expect_addr(0, "descending: hold at address 0");

        // restart has priority over cell_complete
        direction_up = 1;
        @(negedge clk); restart_direction_up = 0; address_restart = 1; cell_complete = 1;
        @(negedge clk); address_restart = 0; cell_complete = 0; #1;
        expect_addr(DEPTH-1, "restart overrides cell_complete");

        // reset returns to 0
        rst = 1; #1;
        @(negedge clk); #1;
        expect_addr(0, "reset to 0");

        $display("----------------------------------------");
        if (errors == 0) $display("ADDRESS GENERATOR TEST PASSED (ADDR_WIDTH=%0d)", ADDR_WIDTH);
        else             $display("ADDRESS GENERATOR TEST FAILED: %0d errors", errors);
        $display("----------------------------------------");
        if (errors != 0) $fatal(1, "address generator errors");
        $finish;
    end
endmodule
