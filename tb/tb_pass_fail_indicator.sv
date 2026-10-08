`timescale 1ns/1ps

module tb_pass_fail_indicator;

    logic clk;
    logic reset;

    logic test_complete;
    logic test_error;

    logic pass_led;
    logic fail_led;
    logic test_done;

    pass_fail_indicator dut (
        .clk(clk),
        .reset(reset),
        .test_complete(test_complete),
        .test_error(test_error),
        .pass_led(pass_led),
        .fail_led(fail_led),
        .test_done(test_done)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        test_complete = 0;
        test_error = 0;

        #12;
        reset = 0;

        // TEST 1: Test running / incomplete
        @(negedge clk);
        test_complete = 0;
        test_error = 0;

        @(posedge clk);
        #1;

        if (pass_led !== 0 ||
            fail_led !== 0 ||
            test_done !== 0) begin
            $display("ERROR: Result appeared before completion");
            $fatal;
        end

        $display("TEST 1 PASSED: No result before completion");

        // TEST 2: Test completed with NO error
        @(negedge clk);
        test_complete = 1;
        test_error = 0;

        @(posedge clk);
        #1;

        if (pass_led !== 1 ||
            fail_led !== 0 ||
            test_done !== 1) begin
            $display("ERROR: PASS result incorrect");
            $fatal;
        end

        $display("TEST 2 PASSED: PASS result");

        // Reset before FAIL test
        @(negedge clk);
        reset = 1;

        @(posedge clk);
        #1;

        reset = 0;

        // TEST 3: Test completed WITH error
        @(negedge clk);
        test_complete = 1;
        test_error = 1;

        @(posedge clk);
        #1;

        if (pass_led !== 0 ||
            fail_led !== 1 ||
            test_done !== 1) begin
            $display("ERROR: FAIL result incorrect");
            $fatal;
        end

        $display("TEST 3 PASSED: FAIL result");

        $display("----------------------------------------");
        $display("PASS/FAIL INDICATOR TEST PASSED");
        $display("----------------------------------------");

        $finish;
    end

endmodule