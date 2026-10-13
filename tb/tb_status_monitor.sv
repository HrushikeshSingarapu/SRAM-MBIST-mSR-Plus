`timescale 1ns/1ps

module tb_status_monitor;
    logic clk, rst, start, mismatch, done;
    logic fault_detected;

    status_monitor dut (
        .clk(clk), .rst(rst), .start(start), .mismatch(mismatch),
        .done(done), .fault_detected(fault_detected)
    );

    always #5 clk = ~clk;

    initial begin
        clk=0; rst=1; start=0; mismatch=0; done=0;
        repeat (2) @(posedge clk);
        rst=0;

        @(negedge clk); start=1;
        @(posedge clk); #1;
        start=0;
        if (fault_detected !== 0) $fatal(1, "Start did not clear fault status");

        @(negedge clk); mismatch=1;
        @(posedge clk); #1; mismatch=0;
        if (fault_detected !== 1) $fatal(1, "Mismatch was not latched");

        @(negedge clk); done=1;
        @(posedge clk); #1; done=0;
        if (fault_detected !== 1) $fatal(1, "Fault status did not persist through done");

        @(negedge clk); start=1;
        @(posedge clk); #1; start=0;
        if (fault_detected !== 0) $fatal(1, "New start did not clear fault status");

        $display("----------------------------------------");
        $display("STATUS MONITOR TEST PASSED");
        $display("----------------------------------------");
        $finish;
    end
endmodule
