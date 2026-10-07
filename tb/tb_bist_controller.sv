`timescale 1ns/1ps

module tb_bist_controller;

    //============================================================
    // Signals
    //============================================================

    logic clk;
    logic reset;
    logic start;

    // 1-bit status from Address Generator:
    // 1 = current address is the last address
    logic last_addr;

    logic test_done;
    logic busy;

    logic direction_up;
    logic restart_direction_up;

    logic cell_complete;
    logic step_complete;
    logic address_restart;

    logic [3:0] march_step;
    logic [1:0] operation_index;


    //============================================================
    // DUT
    //============================================================

    bist_controller dut (
        .clk                   (clk),
        .reset                 (reset),
        .start                 (start),
        .last_addr             (last_addr),

        .test_done             (test_done),
        .busy                  (busy),

        .direction_up          (direction_up),
        .restart_direction_up  (restart_direction_up),

        .cell_complete         (cell_complete),
        .step_complete         (step_complete),
        .address_restart       (address_restart),

        .march_step            (march_step),
        .operation_index       (operation_index)
    );


    //============================================================
    // Clock
    //============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    //============================================================
    // Expected 22-operation mSR+ sequence
    //
    // S0  : w0
    // S1  : w1
    // S2  : r1,w0
    // S3  : r0
    // S4  : r0
    // S5  : r0,w1
    // S6  : r1,w1
    // S7  : r1,w0,w1
    // S8  : r1,w0
    // S9  : r0,w1
    // S10 : r1
    // S11 : r1
    // S12 : r1,w0,r0
    //============================================================

    integer expected_step [0:21];
    integer expected_op   [0:21];

    integer i;
    integer errors;


    //============================================================
    // Test
    //============================================================

    initial begin

        //--------------------------------------------------------
        // Expected sequence
        //--------------------------------------------------------

        expected_step[0]  = 0;
        expected_op[0]    = 0;

        expected_step[1]  = 1;
        expected_op[1]    = 0;

        expected_step[2]  = 2;
        expected_op[2]    = 0;

        expected_step[3]  = 2;
        expected_op[3]    = 1;

        expected_step[4]  = 3;
        expected_op[4]    = 0;

        expected_step[5]  = 4;
        expected_op[5]    = 0;

        expected_step[6]  = 5;
        expected_op[6]    = 0;

        expected_step[7]  = 5;
        expected_op[7]    = 1;

        expected_step[8]  = 6;
        expected_op[8]    = 0;

        expected_step[9]  = 6;
        expected_op[9]    = 1;

        expected_step[10] = 7;
        expected_op[10]   = 0;

        expected_step[11] = 7;
        expected_op[11]   = 1;

        expected_step[12] = 7;
        expected_op[12]   = 2;

        expected_step[13] = 8;
        expected_op[13]   = 0;

        expected_step[14] = 8;
        expected_op[14]   = 1;

        expected_step[15] = 9;
        expected_op[15]   = 0;

        expected_step[16] = 9;
        expected_op[16]   = 1;

        expected_step[17] = 10;
        expected_op[17]   = 0;

        expected_step[18] = 11;
        expected_op[18]   = 0;

        expected_step[19] = 12;
        expected_op[19]   = 0;

        expected_step[20] = 12;
        expected_op[20]   = 1;

        expected_step[21] = 12;
        expected_op[21]   = 2;


        //--------------------------------------------------------
        // Initial conditions
        //--------------------------------------------------------

        reset    = 1'b1;
        start    = 1'b0;

        // Single-address controller test.
        // Therefore the current address is always the last address.
        last_addr = 1'b1;

        errors = 0;


        //--------------------------------------------------------
        // Reset
        //--------------------------------------------------------

        #20;

        reset = 1'b0;


        //--------------------------------------------------------
        // Start MBIST
        //--------------------------------------------------------

        @(negedge clk);

        start = 1'b1;

        @(negedge clk);

        start = 1'b0;


        //--------------------------------------------------------
        // Header
        //--------------------------------------------------------

        $display("");
        $display("========================================");
        $display("       BIST CONTROLLER TEST");
        $display("========================================");
        $display("Testing March mSR+ 22-operation sequence");
        $display("Single-address test: last_addr = 1");
        $display("");


        //========================================================
        // IMPORTANT:
        //
        // The controller entered S0 at the posedge between the
        // two start edges above.
        //
        // Therefore we check the CURRENT outputs first instead
        // of waiting another posedge.
        //========================================================

        #1;


        //========================================================
        // Check all 22 operations
        //========================================================

        for (i = 0; i < 22; i = i + 1) begin

            //----------------------------------------------------
            // Check BUSY
            //----------------------------------------------------

            if (busy !== 1'b1) begin

                $error(
                    "Operation %0d: BUSY should be 1",
                    i
                );

                errors = errors + 1;

            end


            //----------------------------------------------------
            // Check March step
            //----------------------------------------------------

            if (march_step !== expected_step[i]) begin

                $error(
                    "Operation %0d: Expected S%0d, got S%0d",
                    i,
                    expected_step[i],
                    march_step
                );

                errors = errors + 1;

            end


            //----------------------------------------------------
            // Check operation index
            //----------------------------------------------------

            if (operation_index !== expected_op[i]) begin

                $error(
                    "Operation %0d: S%0d expected OP%0d, got OP%0d",
                    i,
                    expected_step[i],
                    expected_op[i],
                    operation_index
                );

                errors = errors + 1;

            end


            //----------------------------------------------------
            // Check current traversal direction
            //----------------------------------------------------

            if (expected_step[i] <= 7) begin

                if (direction_up !== 1'b1) begin

                    $error(
                        "Operation %0d: S%0d should be ascending",
                        i,
                        expected_step[i]
                    );

                    errors = errors + 1;

                end

            end
            else begin

                if (direction_up !== 1'b0) begin

                    $error(
                        "Operation %0d: S%0d should be descending",
                        i,
                        expected_step[i]
                    );

                    errors = errors + 1;

                end

            end


            //----------------------------------------------------
            // Check restart direction
            //
            // S0-S6 -> next element is still ascending
            // S7-S12 -> next element is descending
            //----------------------------------------------------

            if (expected_step[i] <= 6) begin

                if (restart_direction_up !== 1'b1) begin

                    $error(
                        "Operation %0d: S%0d should restart upward",
                        i,
                        expected_step[i]
                    );

                    errors = errors + 1;

                end

            end
            else begin

                if (restart_direction_up !== 1'b0) begin

                    $error(
                        "Operation %0d: S%0d should restart downward",
                        i,
                        expected_step[i]
                    );

                    errors = errors + 1;

                end

            end


            //----------------------------------------------------
            // Display operation
            //----------------------------------------------------

            $display(
                "OP %0d : S%0d  Operation %0d  Direction=%s",
                i,
                march_step,
                operation_index,
                direction_up ? "UP" : "DOWN"
            );


            //----------------------------------------------------
            // Move to next operation
            //
            // Do NOT wait after the final operation here.
            //----------------------------------------------------

            if (i < 21) begin

                @(posedge clk);
                #1;

            end

        end


        //========================================================
        // After final operation S12 OP2
        //
        // Next clock must enter DONE.
        //========================================================

        @(posedge clk);
        #1;


        //--------------------------------------------------------
        // Check DONE
        //--------------------------------------------------------

        if (test_done !== 1'b1) begin

            $error(
                "Controller did not enter DONE after 22 operations"
            );

            errors = errors + 1;

        end
        else begin

            $display("");
            $display("DONE state detected correctly");

        end


        //--------------------------------------------------------
        // Check BUSY is low in DONE
        //--------------------------------------------------------

        if (busy !== 1'b0) begin

            $error(
                "BUSY should be 0 in DONE state"
            );

            errors = errors + 1;

        end


        //--------------------------------------------------------
        // Final result
        //--------------------------------------------------------

        $display("");
        $display("----------------------------------------");

        if (errors == 0) begin

            $display("All 22 mSR+ operations verified");
            $display("mSR+ controller sequence completed");
            $display("BIST CONTROLLER TEST PASSED");

        end
        else begin

            $display(
                "BIST CONTROLLER TEST FAILED: %0d errors",
                errors
            );

        end

        $display("----------------------------------------");


        #10;

        $finish;

    end

endmodule