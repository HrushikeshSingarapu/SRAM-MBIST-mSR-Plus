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
    // 100 MHz
    // ------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // ------------------------------------------------
    // Test sequence
    // ------------------------------------------------
    initial begin

        // Initial values
        rst                  = 1'b1;
        start                = 1'b0;
        direction_up         = 1'b1;
        restart_direction_up = 1'b1;
        cell_complete        = 1'b0;
        address_restart      = 1'b0;


        // =================================================
        // TEST 1: RESET
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 1: RESET");
        $display("========================================");

        #20;

        rst = 1'b0;

        #10;

        $display("Address after reset = %0d", addr);

        if (addr !== '0)
            $fatal(1, "TEST 1 FAILED: Reset address is not 0");
        else
            $display("PASS: Reset address is 0");


        // =================================================
        // TEST 2: START ASCENDING
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 2: START ASCENDING");
        $display("========================================");

        direction_up = 1'b1;
        start       = 1'b1;

        @(posedge clk);
        #1;

        start = 1'b0;

        $display("Address = %0d", addr);

        if (addr !== 0)
            $fatal(1, "TEST 2 FAILED: Ascending did not start at 0");
        else
            $display("PASS: Ascending starts at address 0");


        // =================================================
        // TEST 3: ASCENDING ADDRESS GENERATION
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 3: ASCENDING ADDRESS GENERATION");
        $display("========================================");

        for (int expected_addr = 1;
             expected_addr <= 5;
             expected_addr++) begin

            cell_complete = 1'b1;

            @(posedge clk);
            #1;

            cell_complete = 1'b0;

            $display("Address = %0d, Expected = %0d, last_addr = %b",
                     addr, expected_addr, last_addr);

            if (addr !== expected_addr)
                $fatal(1,
                       "TEST 3 FAILED: Expected address %0d, got %0d",
                       expected_addr, addr);

        end

        $display("PASS: Ascending address generation");


        // =================================================
        // TEST 4: ASCENDING TO LAST ADDRESS
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 4: ASCENDING TO LAST ADDRESS");
        $display("========================================");

        while (addr != 15) begin

            cell_complete = 1'b1;

            @(posedge clk);
            #1;

            cell_complete = 1'b0;

        end

        $display("Address = %0d", addr);
        $display("last_addr = %b", last_addr);

        if (last_addr !== 1'b1)
            $fatal(1, "TEST 4 FAILED: Last ascending address not detected");
        else
            $display("PASS: Last ascending address detected");


        // =================================================
        // TEST 5: RESTART ASCENDING
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 5: RESTART ASCENDING");
        $display("========================================");

        restart_direction_up = 1'b1;
        address_restart      = 1'b1;

        @(posedge clk);
        #1;

        address_restart = 1'b0;

        $display("Address after restart = %0d", addr);

        if (addr !== 0)
            $fatal(1, "TEST 5 FAILED: Ascending restart did not go to 0");
        else
            $display("PASS: Ascending restart goes to 0");


        // =================================================
        // TEST 6: START DESCENDING
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 6: START DESCENDING");
        $display("========================================");

        direction_up = 1'b0;
        start       = 1'b1;

        @(posedge clk);
        #1;

        start = 1'b0;

        $display("Address = %0d", addr);

        if (addr !== 15)
            $fatal(1, "TEST 6 FAILED: Descending did not start at 15");
        else
            $display("PASS: Descending starts at MAX_ADDR");


        // =================================================
        // TEST 7: DESCENDING ADDRESS GENERATION
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 7: DESCENDING ADDRESS GENERATION");
        $display("========================================");

        for (int expected_addr = 14;
             expected_addr >= 10;
             expected_addr--) begin

            cell_complete = 1'b1;

            @(posedge clk);
            #1;

            cell_complete = 1'b0;

            $display("Address = %0d, Expected = %0d, last_addr = %b",
                     addr, expected_addr, last_addr);

            if (addr !== expected_addr)
                $fatal(1,
                       "TEST 7 FAILED: Expected address %0d, got %0d",
                       expected_addr, addr);

        end

        $display("PASS: Descending address generation");


        // =================================================
        // TEST 8: DESCENDING TO ADDRESS 0
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 8: DESCENDING TO ADDRESS 0");
        $display("========================================");

        while (addr != 0) begin

            cell_complete = 1'b1;

            @(posedge clk);
            #1;

            cell_complete = 1'b0;

        end

        $display("Address = %0d", addr);
        $display("last_addr = %b", last_addr);

        if (last_addr !== 1'b1)
            $fatal(1, "TEST 8 FAILED: Last descending address not detected");
        else
            $display("PASS: Last descending address detected");


        // =================================================
        // TEST 9: S7 -> S8 RESTART
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 9: S7 -> S8 RESTART");
        $display("========================================");

        // -----------------------------------------------
        // Current March element: S7 ascending
        // -----------------------------------------------
        direction_up = 1'b1;

        // Start ascending traversal at address 0
        start = 1'b1;

        @(posedge clk);
        #1;

        start = 1'b0;

        // Move all the way to MAX_ADDR
        while (addr != 15) begin

            cell_complete = 1'b1;

            @(posedge clk);
            #1;

            cell_complete = 1'b0;

        end

        // Verify S7 ended at address 15
        $display("S7 final address = %0d", addr);

        if (addr !== 15)
            $fatal(1, "TEST 9 FAILED: S7 did not finish at address 15");

        if (last_addr !== 1'b1)
            $fatal(1, "TEST 9 FAILED: last_addr not asserted at address 15");

        // -----------------------------------------------
        // Next March element: S8 descending
        // -----------------------------------------------
        restart_direction_up = 1'b0;
        address_restart      = 1'b1;

        @(posedge clk);
        #1;

        address_restart = 1'b0;

        $display("S8 starting address = %0d", addr);

        // S8 descending must restart from MAX_ADDR
        if (addr !== 15)
            $fatal(1,
                   "TEST 9 FAILED: S8 did not restart at MAX_ADDR");

        if (last_addr !== 1'b0)
            $fatal(1,
                   "TEST 9 FAILED: S8 direction is not descending");

        $display("PASS: S7 -> S8 correctly restarts at MAX_ADDR");


        // =================================================
        // FINISH
        // =================================================

        $display("");
        $display("========================================");
        $display("ALL ADDRESS GENERATOR TESTS PASSED");
        $display("========================================");

        #20;

        $finish;

    end

endmodule
