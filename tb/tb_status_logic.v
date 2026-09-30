`timescale 1ns/1ps

module tb_status_logic;

    reg clk;
    reg rst;
    reg start;
    reg mismatch;
    reg controller_busy;
    reg controller_done;

    wire fault;
    wire done;
    wire busy;
    wire pass;
    wire fail;

    status_logic uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mismatch(mismatch),
        .controller_busy(controller_busy),
        .controller_done(controller_done),
        .fault(fault),
        .done(done),
        .busy(busy),
        .pass(pass),
        .fail(fail)
    );

    // Clock generation: 10 ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $monitor("Time=%0t | Reset=%b | Start=%b | Mismatch=%b | Busy=%b | Done=%b | Fault=%b | Pass=%b | Fail=%b",
                 $time, rst, start, mismatch, busy, done, fault, pass, fail);

        // Initialize inputs
        rst = 1;
        start = 0;
        mismatch = 0;
        controller_busy = 0;
        controller_done = 0;

        // Test 1: Reset
        @(posedge clk);
        #1;
        if (fault !== 0 || done !== 0)
            $fatal(1, "TEST 1 FAILED: Reset");
        $display("TEST 1 PASSED: Reset");

        // Release reset
        @(negedge clk);
        rst = 0;

        // Test 2: Busy status
        controller_busy = 1;
        @(posedge clk);
        #1;
        if (busy !== 1)
            $fatal(1, "TEST 2 FAILED: Busy status");
        $display("TEST 2 PASSED: Busy status");

        // Test 3: Fault detection
        @(negedge clk);
        mismatch = 1;
        @(posedge clk);
        #1;
        if (fault !== 1)
            $fatal(1, "TEST 3 FAILED: Fault detection");
        $display("TEST 3 PASSED: Fault detection");

        // Test 4: Fault remains latched
        @(negedge clk);
        mismatch = 0;
        @(posedge clk);
        #1;
        if (fault !== 1)
            $fatal(1, "TEST 4 FAILED: Fault latching");
        $display("TEST 4 PASSED: Fault remains latched");

        // Test 5: Completion and fail status
        @(negedge clk);
        controller_busy = 0;
        controller_done = 1;
        @(posedge clk);
        #1;
        if (done !== 1 || fail !== 1 || pass !== 0)
            $fatal(1, "TEST 5 FAILED: Fail status");
        $display("TEST 5 PASSED: Completion and fail status");

        // Test 6: Start a new test and clear previous status
        @(negedge clk);
        controller_done = 0;
        start = 1;
        @(posedge clk);
        #1;
        if (fault !== 0 || done !== 0)
            $fatal(1, "TEST 6 FAILED: Clear on start");
        $display("TEST 6 PASSED: Status cleared on start");

        // Test 7: Successful test
        @(negedge clk);
        start = 0;
        controller_busy = 1;
        mismatch = 0;
        @(posedge clk);
        #1;
        if (fault !== 0 || busy !== 1)
            $fatal(1, "TEST 7 FAILED: No-fault operation");
        $display("TEST 7 PASSED: No-fault operation");

        // Test 8: Completion and pass status
        @(negedge clk);
        controller_busy = 0;
        controller_done = 1;
        @(posedge clk);
        #1;
        if (done !== 1 || pass !== 1 || fail !== 0)
            $fatal(1, "TEST 8 FAILED: Pass status");
        $display("TEST 8 PASSED: Completion and pass status");

        $display("-----------------------------");
        $display("ALL STATUS LOGIC TESTS PASSED");
        $display("-----------------------------");

        $finish;
    end

endmodule
