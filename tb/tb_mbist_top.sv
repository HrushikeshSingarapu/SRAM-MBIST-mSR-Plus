//============================================================
// MBIST TOP TESTBENCH
//
// Tests:
//  1. No fault
//  2. SAF
//  3. TF
//  4. CFID
//  5. CFDRD
//  6. CFIN
//  7. RDF
//  8. DRDF
//  9. IRF
// 10. CFTR
// 11. CFWD
// 12. WDF
//
// This verifies the integrated MBIST infrastructure.
//
//============================================================

`timescale 1ns/1ps

module tb_mbist_top;

    //--------------------------------------------------------
    // Parameters
    //--------------------------------------------------------

    localparam int ADDR_WIDTH = 3;
    localparam int DATA_WIDTH = 8;

    //--------------------------------------------------------
    // Clock/reset
    //--------------------------------------------------------

    logic clk;
    logic rst;
    logic start;

    //--------------------------------------------------------
    // Fault configuration
    //--------------------------------------------------------

    logic fault_enable;
    logic [3:0] fault_type;

    logic [ADDR_WIDTH-1:0] fault_address;
    logic [ADDR_WIDTH-1:0] aggressor_address;

    logic stuck_at_value;

    //--------------------------------------------------------
    // MBIST outputs
    //--------------------------------------------------------

    logic busy;
    logic done;
    logic pass;
    logic fail;

    logic [ADDR_WIDTH-1:0] current_address;

    logic [3:0] march_step;
    logic [1:0] operation_index;

    logic direction_up;

    //--------------------------------------------------------
    // Fault constants
    //--------------------------------------------------------

    localparam logic [3:0] FAULT_SAF   = 4'd0;
    localparam logic [3:0] FAULT_TF    = 4'd1;
    localparam logic [3:0] FAULT_CFID  = 4'd2;
    localparam logic [3:0] FAULT_CFDRD = 4'd3;
    localparam logic [3:0] FAULT_CFIN  = 4'd4;
    localparam logic [3:0] FAULT_RDF   = 4'd5;
    localparam logic [3:0] FAULT_DRDF  = 4'd6;
    localparam logic [3:0] FAULT_IRF   = 4'd7;
    localparam logic [3:0] FAULT_CFTR  = 4'd8;
    localparam logic [3:0] FAULT_CFWD  = 4'd9;
    localparam logic [3:0] FAULT_WDF   = 4'd10;

    //--------------------------------------------------------
    // Clock
    //--------------------------------------------------------

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end

    //--------------------------------------------------------
    // DUT
    //--------------------------------------------------------

    mbist_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (

        .clk(clk),
        .rst(rst),
        .start(start),

        .fault_enable(fault_enable),
        .fault_type(fault_type),

        .fault_address(fault_address),
        .aggressor_address(aggressor_address),

        .stuck_at_value(stuck_at_value),

        .busy(busy),
        .done(done),
        .pass(pass),
        .fail(fail),

        .current_address(current_address),

        .march_step(march_step),
        .operation_index(operation_index),

        .direction_up(direction_up)

    );

    //--------------------------------------------------------
    // Reset
    //--------------------------------------------------------

    task reset_dut;

        begin

            rst = 1'b1;
            start = 1'b0;

            fault_enable = 1'b0;
            fault_type = 4'd0;

            fault_address = '0;
            aggressor_address = '0;

            stuck_at_value = 1'b0;

            #20;

            rst = 1'b0;

            #10;

        end

    endtask

    //--------------------------------------------------------
    // Start MBIST
    //
    // Start is driven on the negative clock edge so that
    // the DUT samples a stable value on the next positive
    // edge.
    //
    // PASS/FAIL are also checked after a negative edge so
    // that registered DUT outputs have settled.
    //--------------------------------------------------------

    task start_mbist;

        begin

            //------------------------------------------------
            // Assert START away from DUT sampling edge
            //------------------------------------------------

            @(negedge clk);

            start = 1'b1;

            //------------------------------------------------
            // DUT samples START on following posedge
            //------------------------------------------------

            @(negedge clk);

            start = 1'b0;

            //------------------------------------------------
            // Wait for MBIST completion
            //------------------------------------------------

            wait(done);

            //------------------------------------------------
            // Allow registered PASS/FAIL to update on posedge clk
            //------------------------------------------------

            @(posedge clk);
            @(negedge clk);

        end

    endtask

    //--------------------------------------------------------
    // Display current operation
    //
    // Use negedge so displayed values correspond to the
    // settled post-clock state.
    //--------------------------------------------------------

    always @(negedge clk) begin

        if (busy) begin

            $display(
                "T=%0t | STEP=S%0d | OP=%0d | ADDR=%0d | DIR=%s",
                $time,
                march_step,
                operation_index,
                current_address,
                direction_up ? "UP" : "DOWN"
            );

        end

    end

    //--------------------------------------------------------
    // Main test sequence
    //--------------------------------------------------------

    initial begin

        //----------------------------------------------------
        // Test 1: No fault
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 1: NO FAULT");
        $display("======================================");

        fault_enable = 1'b0;

        start_mbist;

        if (pass && !fail)
            $display("PASS: No-fault MBIST completed successfully.");
        else
            $display("FAIL: No-fault MBIST failed.");

        //----------------------------------------------------
        // Test 2: SAF
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 2: SAF");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_SAF;

        fault_address = 3'd3;
        stuck_at_value = 1'b0;

        start_mbist;

        if (fail)
            $display("PASS: SAF detected.");
        else
            $display("FAIL: SAF was not detected.");

        //----------------------------------------------------
        // Test 3: TF
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 3: TF");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_TF;

        fault_address = 3'd3;

        start_mbist;

        if (fail)
            $display("PASS: TF detected.");
        else
            $display("FAIL: TF was not detected.");

        //----------------------------------------------------
        // Test 4: CFID
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 4: CFID");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_CFID;

        aggressor_address = 3'd2;
        fault_address = 3'd3;

        start_mbist;

        if (fail)
            $display("PASS: CFID detected.");
        else
            $display("FAIL: CFID was not detected.");

        //----------------------------------------------------
        // Test 5: CFDRD
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 5: CFDRD");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_CFDRD;

        aggressor_address = 3'd2;
        fault_address = 3'd3;

        start_mbist;

        if (fail)
            $display("PASS: CFDRD detected.");
        else
            $display("FAIL: CFDRD was not detected.");

        //----------------------------------------------------
        // Test 6: CFIN
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 6: CFIN");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_CFIN;

        aggressor_address = 3'd2;
        fault_address = 3'd3;

        start_mbist;

        if (fail)
            $display("PASS: CFIN detected.");
        else
            $display("FAIL: CFIN was not detected.");

        //----------------------------------------------------
        // Test 7: RDF
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 7: RDF");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_RDF;

        fault_address = 3'd3;

        start_mbist;

        if (fail)
            $display("PASS: RDF detected.");
        else
            $display("FAIL: RDF was not detected.");

        //----------------------------------------------------
        // Test 8: DRDF
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 8: DRDF");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_DRDF;

        fault_address = 3'd3;

        start_mbist;

        if (fail)
            $display("PASS: DRDF detected.");
        else
            $display("FAIL: DRDF was not detected.");

        //----------------------------------------------------
        // Test 9: IRF
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 9: IRF");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_IRF;

        fault_address = 3'd3;

        start_mbist;

        if (fail)
            $display("PASS: IRF detected.");
        else
            $display("FAIL: IRF was not detected.");

        //----------------------------------------------------
        // Test 10: CFTR
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 10: CFTR");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_CFTR;

        aggressor_address = 3'd2;
        fault_address = 3'd3;

        start_mbist;

        if (fail)
            $display("PASS: CFTR detected.");
        else
            $display("FAIL: CFTR was not detected.");

        //----------------------------------------------------
        // Test 11: CFWD
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 11: CFWD");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_CFWD;

        aggressor_address = 3'd2;
        fault_address = 3'd3;

        start_mbist;

        if (fail)
            $display("PASS: CFWD detected.");
        else
            $display("FAIL: CFWD was not detected.");

        //----------------------------------------------------
        // Test 12: WDF
        //----------------------------------------------------

        reset_dut;

        $display("\n======================================");
        $display("TEST 12: WDF");
        $display("======================================");

        fault_enable = 1'b1;
        fault_type = FAULT_WDF;

        fault_address = 3'd3;

        start_mbist;

        if (fail)
            $display("PASS: WDF detected.");
        else
            $display("FAIL: WDF was not detected.");

        //----------------------------------------------------
        // End
        //----------------------------------------------------

        $display("\n======================================");
        $display("ALL MBIST INTEGRATION TESTS FINISHED");
        $display("======================================");

        $finish;

    end

endmodule
