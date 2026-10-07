//============================================================
// Testbench: Complete SRAM MBIST Top
//
// Tests the integrated MBIST system:
//
//   MBIST Controller
//        |
//        v
//   Address Generator
//        |
//        v
//   Pattern Controller
//        |
//        v
//      SRAM
//        |
//        v
//    Comparator
//        |
//        v
//    Status Logic
//
// Algorithm:
//     March mSR+
//
// Test configuration:
//     ADDR_WIDTH = 4  -> 16 memory locations
//     DATA_WIDTH = 8
//
//============================================================

`timescale 1ns/1ps

module tb_mbist_top;

    //--------------------------------------------------------
    // Parameters
    //--------------------------------------------------------

    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 8;


    //--------------------------------------------------------
    // Testbench signals
    //--------------------------------------------------------

    logic clk;
    logic rst;
    logic start;

    logic busy;
    logic done;
    logic pass;
    logic fail;
    logic fault;


    //--------------------------------------------------------
    // DUT
    //--------------------------------------------------------

    mbist_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (

        .clk   (clk),
        .rst   (rst),
        .start (start),

        .busy  (busy),
        .done  (done),
        .pass  (pass),
        .fail  (fail),
        .fault (fault)

    );


    //--------------------------------------------------------
    // Clock generation
    //--------------------------------------------------------

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    //--------------------------------------------------------
    // Main test
    //--------------------------------------------------------

    initial begin

        //----------------------------------------------------
        // Initial values
        //----------------------------------------------------

        rst   = 1'b1;
        start = 1'b0;


        //----------------------------------------------------
        // Reset
        //----------------------------------------------------

        #20;

        rst = 1'b0;

        //----------------------------------------------------
        // Wait one clock cycle
        //----------------------------------------------------

        #10;


        //----------------------------------------------------
        // Start MBIST
        //----------------------------------------------------

        start = 1'b1;

        #10;

        start = 1'b0;


        //----------------------------------------------------
        // Wait for complete MBIST operation
        //----------------------------------------------------

        wait (done == 1'b1);


        //----------------------------------------------------
        // Display final result
        //----------------------------------------------------

        #10;

        $display("==============================================");
        $display("        COMPLETE MBIST TEST RESULT");
        $display("==============================================");

        $display("BUSY  = %b", busy);
        $display("DONE  = %b", done);
        $display("FAULT = %b", fault);
        $display("PASS  = %b", pass);
        $display("FAIL  = %b", fail);

        $display("==============================================");


        //----------------------------------------------------
        // Automatic result check
        //----------------------------------------------------

        if (done !== 1'b1) begin

            $display("ERROR: MBIST did not complete.");
            $fatal;

        end

        if (fault !== 1'b0) begin

            $display("ERROR: Unexpected fault detected.");
            $fatal;

        end

        if (pass !== 1'b1) begin

            $display("ERROR: MBIST did not report PASS.");
            $fatal;

        end

        if (fail !== 1'b0) begin

            $display("ERROR: MBIST reported FAIL.");
            $fatal;

        end


        //----------------------------------------------------
        // Successful completion
        //----------------------------------------------------

        $display("==============================================");
        $display("       MBIST TOP TEST PASSED");
        $display("       mSR+ NORMAL MEMORY TEST PASSED");
        $display("==============================================");


        #20;

        $finish;

    end


    //--------------------------------------------------------
    // Monitor top-level signals
    //--------------------------------------------------------

    initial begin

        $monitor(
            "TIME=%0t | rst=%b | start=%b | busy=%b | done=%b | fault=%b | pass=%b | fail=%b",

            $time,
            rst,
            start,
            busy,
            done,
            fault,
            pass,
            fail
        );

    end

endmodule