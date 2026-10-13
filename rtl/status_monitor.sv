//============================================================
// Status Monitor
//============================================================

module status_monitor (

    input logic clk,
    input logic rst,

    input logic start,
    input logic mismatch,
    input logic done,

    output logic fault_detected

);

    //--------------------------------------------------------
    // Fault detection latch
    //--------------------------------------------------------

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            fault_detected <= 1'b0;

        end

        else begin

            //------------------------------------------------
            // Clear when a new test starts
            //------------------------------------------------

            if (start)
                fault_detected <= 1'b0;

            //------------------------------------------------
            // Remember any mismatch
            //------------------------------------------------

            if (mismatch)
                fault_detected <= 1'b1;

        end

    end

endmodule
