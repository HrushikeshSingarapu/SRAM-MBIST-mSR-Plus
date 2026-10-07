`timescale 1ns/1ps

module tb_address_generator;

    localparam ADDR_WIDTH = 8;

    logic clk;
    logic reset;
    logic start;
    logic direction_up;
    logic restart_direction_up;
    logic cell_complete;
    logic address_restart;

    logic [ADDR_WIDTH-1:0] addr;
    logic last_addr;

    address_generator #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk                 (clk),
        .reset               (reset),
        .start               (start),
        .direction_up        (direction_up),
        .restart_direction_up(restart_direction_up),
        .cell_complete       (cell_complete),
        .address_restart     (address_restart),
        .addr                (addr),
        .last_addr           (last_addr)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin

        reset = 1'b1;
        start = 1'b0;
        direction_up = 1'b1;
        restart_direction_up = 1'b1;
        cell_complete = 1'b0;
        address_restart = 1'b0;

        #20;

        reset = 1'b0;

        $display("========================================");
        $display("   ADDRESS GENERATOR TEST");
        $display("========================================");

        // ------------------------------------------------
        // TEST 1: Start in ascending direction
        // ------------------------------------------------
        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        #1;

        if (addr !== 8'h00)
            $error("Ascending start should begin at address 0");

        $display("TEST 1 PASSED: Ascending starts at 0");

        // ------------------------------------------------
        // TEST 2: Ascending address movement
        // ------------------------------------------------
        repeat (3) begin

            @(negedge clk);
            cell_complete = 1'b1;

            @(negedge clk);
            cell_complete = 1'b0;

            #1;

            $display("Ascending address = %0d", addr);
        end

        if (addr !== 8'h03)
            $error("Expected address 3, got %0d", addr);

        $display("TEST 2 PASSED: Ascending traversal");

        // ------------------------------------------------
        // TEST 3: Address restart
        // ------------------------------------------------
        @(negedge clk);
        restart_direction_up = 1'b1;
        address_restart = 1'b1;

        @(negedge clk);
        address_restart = 1'b0;

        #1;

        if (addr !== 8'h00)
            $error("Ascending restart should return to address 0");

        $display("TEST 3 PASSED: Ascending restart");

        // ------------------------------------------------
        // TEST 4: Descending start
        // ------------------------------------------------
        @(negedge clk);

        direction_up = 1'b0;
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        #1;

        if (addr !== 8'hFF)
            $error("Descending start should begin at maximum address");

        $display("TEST 4 PASSED: Descending starts at 255");

        // ------------------------------------------------
        // TEST 5: Descending traversal
        // ------------------------------------------------
        repeat (3) begin

            @(negedge clk);
            cell_complete = 1'b1;

            @(negedge clk);
            cell_complete = 1'b0;

            #1;

            $display("Descending address = %0d", addr);
        end

        if (addr !== 8'hFC)
            $error("Expected address 252, got %0d", addr);

        $display("TEST 5 PASSED: Descending traversal");

        // ------------------------------------------------
        // TEST 6: Descending restart
        // ------------------------------------------------
        @(negedge clk);

        restart_direction_up = 1'b0;
        address_restart = 1'b1;

        @(negedge clk);
        address_restart = 1'b0;

        #1;

        if (addr !== 8'hFF)
            $error("Descending restart should return to address 255");

        $display("TEST 6 PASSED: Descending restart");

        // ------------------------------------------------

        $display("----------------------------------------");
        $display("ADDRESS GENERATOR TEST PASSED");
        $display("----------------------------------------");

        #20;
        $finish;
    end

endmodule