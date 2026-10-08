`timescale 1ns/1ps

module tb_status_monitor;

    logic clk;
    logic reset;

    logic bist_busy;
    logic test_done;
    logic fault_detected;

    logic test_active;
    logic test_complete;
    logic test_error;

    status_monitor dut (
        .clk(clk),
        .reset(reset),
        .bist_busy(bist_busy),
        .test_done(test_done),
        .fault_detected(fault_detected),
        .test_active(test_active),
        .test_complete(test_complete),
        .test_error(test_error)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        bist_busy = 0;
        test_done = 0;
        fault_detected = 0;

        #12;
        reset = 0;

        // TEST 1: Idle
        @(negedge clk);
        bist_busy = 0;
        test_done = 0;
        fault_detected = 0;

        @(posedge clk);
        #1;

        if (test_active !== 0 ||
            test_complete !== 0 ||
            test_error !== 0) begin
            $display("ERROR: Idle status incorrect");
            $fatal;
        end

        $display("TEST 1 PASSED: Idle");

        // TEST 2: BIST running
        @(negedge clk);
        bist_busy = 1;

        @(posedge clk);
        #1;

        if (test_active !== 1) begin
            $display("ERROR: Test active not detected");
            $fatal;
        end

        $display("TEST 2 PASSED: BIST active");

        // TEST 3: BIST running with fault
        @(negedge clk);
        fault_detected = 1;

        @(posedge clk);
        #1;

        if (test_error !== 1) begin
            $display("ERROR: Test error not detected");
            $fatal;
        end

        $display("TEST 3 PASSED: Fault status");

        // TEST 4: Test completes
        @(negedge clk);
        bist_busy = 0;
        test_done = 1;

        @(posedge clk);
        #1;

        if (test_complete !== 1) begin
            $display("ERROR: Test completion not detected");
            $fatal;
        end

        $display("TEST 4 PASSED: Test complete");

        $display("----------------------------------------");
        $display("STATUS MONITOR TEST PASSED");
        $display("----------------------------------------");

        $finish;
    end

endmodule