module status_logic (
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire mismatch,
    input  wire controller_busy,
    input  wire controller_done,
    output reg  fault,
    output reg  done,
    output wire busy,
    output wire pass,
    output wire fail
);
    // Reflect the controller's busy status; do not create a second busy state.
    assign busy = controller_busy;

    // Synchronous, active-high reset.
    always @(posedge clk) begin
        if (rst) begin
            fault <= 1'b0;
            done  <= 1'b0;
        end
        else if (start) begin
            // Clear the previous test result when a new test starts.
            fault <= 1'b0;
            done  <= 1'b0;
        end
        else begin
            // Latch any mismatch observed during the MBIST operation.
            if (mismatch && (controller_busy || controller_done))
                fault <= 1'b1;

            // Latch completion if the controller signals done.
            if (controller_done)
                done <= 1'b1;
        end
    end

    assign pass = done && !fault;
    assign fail = done && fault;
endmodule
