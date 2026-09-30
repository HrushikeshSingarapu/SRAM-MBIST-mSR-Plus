`timescale 1ns/1ps

module address_generator_tb;

    // ------------------------------------------------
    // Parameters
    // ------------------------------------------------
    parameter ADDR_WIDTH = 4;

    // ------------------------------------------------
    // Testbench signals
    // ------------------------------------------------
    logic clk;
    logic rst;
    logic start;

    logic direction_up;
    logic restart_direction_up;
    logic cell_complete;
    logic address_restart;

    logic [ADDR_WIDTH-1:0] addr;
    logic last_addr;

    // ------------------------------------------------
    // DUT
    // ------------------------------------------------
    address_generator #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk                  (clk),
        .rst                  (rst),
        .start                (start),
        .direction_up         (direction_up),
        .restart_direction_up (restart_direction_up),
        .cell_complete        (cell_complete),
        .address_restart      (address_restart),
        .addr                 (addr),
        .last_addr            (last_addr)
    );

    // ------------------------------------------------
    // Clock generation
    // 100 MHz clock
    // ------------------------------------------------
    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end

    // ------------------------------------------------
    // Test
    // ------------------------------------------------
    initial begin

        // Initial values
        rst                  = 1'b1;
        start                = 1'b0;
        direction_up         = 1'b1;
        restart_direction_up = 1'b1;
        cell_complete        = 1'b0;
        address_restart      = 1'b0;

        // --------------------------------------------
        // Reset
        // --------------------------------------------
        $display("----------------------------------------");
        $display("TEST 1: RESET");
        $display("----------------------------------------");

        #20;

        rst = 1'b0;

        #10;

        $display("Address after reset = %0d", addr);

        if (addr == 0)
            $display("PASS: Reset address is 0");
        else
            $display("FAIL: Reset address is not 0");


        // --------------------------------------------
        // TEST 2: Start ascending
        // --------------------------------------------
        $display("----------------------------------------");
        $display("TEST 2: START ASCENDING");
        $display("----------------------------------------");

        direction_up = 1'b1;
        start       = 1'b1;

        @(posedge clk);
        #1;

        start = 1'b0;

        $display("Address = %0d", addr);

        if (addr == 0)
            $display("PASS: Ascending starts at address 0");
        else
            $display("FAIL: Ascending did not start at 0");


        // --------------------------------------------
        // TEST 3: Ascending address generation
        // --------------------------------------------
        $display("----------------------------------------");
        $display("TEST 3: ASCENDING ADDRESS GENERATION");
        $display("----------------------------------------");

        repeat (5) begin

            cell_complete = 1'b1;

            @(posedge clk);
            #1;

            cell_complete = 1'b0;

            $display("Address = %0d, last_addr = %b",
                     addr, last_addr);

        end


        // --------------------------------------------
        // TEST 4: Ascending until last address
        // --------------------------------------------
        $display("----------------------------------------");
        $display("TEST 4: ASCENDING TO LAST ADDRESS");
        $display("----------------------------------------");

        while (addr != 15) begin

            cell_complete = 1'b1;

            @(posedge clk);
            #1;

            cell_complete = 1'b0;

        end

        $display("Address = %0d", addr);
        $display("last_addr = %b", last_addr);

        if (last_addr == 1'b1)
            $display("PASS: Last ascending address detected");
        else
            $display("FAIL: Last ascending address NOT detected");


        // --------------------------------------------
        // TEST 5: Restart ascending
        // --------------------------------------------
        $display("----------------------------------------");
        $display("TEST 5: RESTART ASCENDING");
        $display("----------------------------------------");

        restart_direction_up = 1'b1;
        address_restart      = 1'b1;

        @(posedge clk);
        #1;

        address_restart = 1'b0;

        $display("Address after restart = %0d", addr);

        if (addr == 0)
            $display("PASS: Ascending restart goes to 0");
        else
            $display("FAIL: Ascending restart incorrect");


        // --------------------------------------------
        // TEST 6: Start descending
        // --------------------------------------------
        $display("----------------------------------------");
        $display("TEST 6: START DESCENDING");
        $display("----------------------------------------");

        direction_up = 1'b0;
        start       = 1'b1;

        @(posedge clk);
        #1;

        start = 1'b0;

        $display("Address = %0d", addr);

        if (addr == 15)
            $display("PASS: Descending starts at MAX_ADDR");
        else
            $display("FAIL: Descending did not start at MAX_ADDR");


        // --------------------------------------------
        // TEST 7: Descending address generation
        // --------------------------------------------
        $display("----------------------------------------");
        $display("TEST 7: DESCENDING ADDRESS GENERATION");
        $display("----------------------------------------");

        repeat (5) begin

            cell_complete = 1'b1;

            @(posedge clk);
            #1;

            cell_complete = 1'b0;

            $display("Address = %0d, last_addr = %b",
                     addr, last_addr);

        end


        // --------------------------------------------
        // TEST 8: Descending until address 0
        // --------------------------------------------
        $display("----------------------------------------");
        $display("TEST 8: DESCENDING TO ADDRESS 0");
        $display("----------------------------------------");

        while (addr != 0) begin

            cell_complete = 1'b1;

            @(posedge clk);
            #1;

            cell_complete = 1'b0;

        end

        $display("Address = %0d", addr);
        $display("last_addr = %b", last_addr);

        if (last_addr == 1'b1)
            $display("PASS: Last descending address detected");
        else
            $display("FAIL: Last descending address NOT detected");


        // --------------------------------------------
        // TEST 9:
        // S7 -> S8 transition
        // --------------------------------------------
        $display("----------------------------------------");
        $display("TEST 9: S7 -> S8 RESTART");
        $display("----------------------------------------");

        // Current March element is ascending
        direction_up = 1'b1;

        // Put address at MAX_ADDR
        start = 1'b1;

        @(posedge clk);
        #1;

        start = 1'b0;

        // Next March element is descending
        restart_direction_up = 1'b0;

        address_restart = 1'b1;

        @(posedge clk);
        #1;

        address_restart = 1'b0;

        $display("Address after S7 -> S8 restart = %0d",
                 addr);

        if (addr == 15)
            $display("PASS: S8 correctly starts at MAX_ADDR");
        else
            $display("FAIL: S8 did not start at MAX_ADDR");


        // --------------------------------------------
        // Finish
        // --------------------------------------------
        $display("----------------------------------------");
        $display("ALL ADDRESS GENERATOR TESTS COMPLETED");
        $display("----------------------------------------");

        #20;

        $finish;

    end

endmodule