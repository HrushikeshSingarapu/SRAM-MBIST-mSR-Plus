//============================================================
// Testbench: MBIST Controller
//
// Tests:
// 1. Reset -> IDLE
// 2. Start -> S0
// 3. March sequence S0 -> S12
// 4. Operation index progression
// 5. Address direction
// 6. Restart direction
// 7. Cell completion
// 8. Step completion
// 9. Address restart
// 10. DONE
//
// DUT:
//     mbist_controller.sv
//============================================================

`timescale 1ns/1ps

module tb_mbist_controller;

    //--------------------------------------------------------
    // Testbench signals
    //--------------------------------------------------------

    logic       clk;
    logic       rst;
    logic       start;
    logic       last_addr;

    logic       busy;
    logic       done;

    logic       direction_up;
    logic       restart_direction_up;

    logic       cell_complete;
    logic       step_complete;
    logic       address_restart;

    logic [3:0] march_step;
    logic [1:0] operation_index;


    //--------------------------------------------------------
    // DUT
    //--------------------------------------------------------

    mbist_controller dut (
        .clk                   (clk),
        .rst                   (rst),
        .start                 (start),
        .last_addr             (last_addr),

        .busy                  (busy),
        .done                  (done),

        .direction_up          (direction_up),
        .restart_direction_up  (restart_direction_up),

        .cell_complete         (cell_complete),
        .step_complete         (step_complete),
        .address_restart       (address_restart),

        .march_step            (march_step),
        .operation_index       (operation_index)
    );


    //--------------------------------------------------------
    // Clock generation
    //--------------------------------------------------------

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    //--------------------------------------------------------
    // Test sequence
    //--------------------------------------------------------

    initial begin

        //----------------------------------------------------
        // Initial values
        //----------------------------------------------------

        rst       = 1'b1;
        start     = 1'b0;
        last_addr = 1'b0;


        //----------------------------------------------------
        // Apply reset
        //----------------------------------------------------

        #20;

        rst = 1'b0;


        //----------------------------------------------------
        // Start MBIST
        //----------------------------------------------------

        #10;

        start = 1'b1;

        #10;

        start = 1'b0;


        //----------------------------------------------------
        // Simulate memory traversal
        //
        // For this unit test, last_addr = 1.
        //
        // This allows every March element to complete
        // without requiring a real SRAM/address generator.
        //----------------------------------------------------

        last_addr = 1'b1;


        //----------------------------------------------------
        // Wait until MBIST completes
        //----------------------------------------------------

        wait (done == 1'b1);


        //----------------------------------------------------
        // Small delay for waveform visibility
        //----------------------------------------------------

        #10;


        //----------------------------------------------------
        // End simulation
        //----------------------------------------------------

        $display("==============================================");
        $display("MBIST CONTROLLER TEST COMPLETED");
        $display("==============================================");

        $finish;

    end


    //--------------------------------------------------------
    // Monitor important controller signals
    //--------------------------------------------------------

    initial begin

        $monitor(
            "TIME=%0t | rst=%b | start=%b | busy=%b | step=%0d | op=%0d | dir=%b | restart_dir=%b | cell_done=%b | step_done=%b | restart=%b | done=%b",

            $time,
            rst,
            start,
            busy,
            march_step,
            operation_index,
            direction_up,
            restart_direction_up,
            cell_complete,
            step_complete,
            address_restart,
            done
        );

    end

endmodule
