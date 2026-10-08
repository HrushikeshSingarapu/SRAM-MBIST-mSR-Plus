`timescale 1ns/1ps

module tb_fault_logger;

    logic clk;
    logic reset;

    logic compare_error;
    logic [7:0] addr;
    logic test_done;

    logic [7:0] error_count;
    logic fault_detected;
    logic [7:0] fault_address;

    fault_logger #(
        .ADDR_WIDTH(8)
    ) dut (
        .clk(clk),
        .reset(reset),
        .compare_error(compare_error),
        .addr(addr),
        .test_done(test_done),
        .error_count(error_count),
        .fault_detected(fault_detected),
        .fault_address(fault_address)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        compare_error = 0;
        addr = 8'h00;
        test_done = 0;

        #12;
        reset = 0;

        // TEST 1: No error
        @(negedge clk);
        compare_error = 0;
        addr = 8'h10;

        @(posedge clk);
        #1;

        if (error_count !== 8'd0 ||
            fault_detected !== 1'b0) begin
            $display("ERROR: Unexpected fault");
            $fatal;
        end

        $display("TEST 1 PASSED: No fault");

        // TEST 2: First error
        @(negedge clk);
        compare_error = 1;
        addr = 8'h25;

        @(posedge clk);
        #1;

        if (error_count !== 8'd1 ||
            fault_detected !== 1'b1 ||
            fault_address !== 8'h25) begin
            $display("ERROR: First fault logging failed");
            $fatal;
        end

        $display("TEST 2 PASSED: First fault logged");

        // TEST 3: Second error
        @(negedge clk);
        compare_error = 1;
        addr = 8'h80;

        @(posedge clk);
        #1;

        if (error_count !== 8'd2 ||
            fault_address !== 8'h80) begin
            $display("ERROR: Second fault logging failed");
            $fatal;
        end

        $display("TEST 3 PASSED: Second fault logged");

        // TEST 4: No new error
        @(negedge clk);
        compare_error = 0;
        addr = 8'hA0;

        @(posedge clk);
        #1;

        if (error_count !== 8'd2 ||
            fault_detected !== 1'b1) begin
            $display("ERROR: Fault information was lost");
            $fatal;
        end

        $display("TEST 4 PASSED: Fault information retained");

        // TEST 5: Error at another address
        @(negedge clk);
        compare_error = 1;
        addr = 8'hFF;

        @(posedge clk);
        #1;

        if (error_count !== 8'd3 ||
            fault_address !== 8'hFF) begin
            $display("ERROR: Third fault logging failed");
            $fatal;
        end

        $display("TEST 5 PASSED: Third fault logged");

        $display("----------------------------------------");
        $display("FAULT LOGGER TEST PASSED");
        $display("----------------------------------------");

        $finish;
    end

endmodule