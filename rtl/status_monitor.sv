module status_monitor (
    input  logic clk,
    input  logic reset,

    input  logic bist_busy,
    input  logic test_done,
    input  logic fault_detected,

    output logic test_active,
    output logic test_complete,
    output logic test_error
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            test_active   <= 1'b0;
            test_complete <= 1'b0;
            test_error    <= 1'b0;
        end
        else begin

            // Current test activity
            test_active <= bist_busy;

            // Test completion
            if (test_done)
                test_complete <= 1'b1;

            // Error status
            if (fault_detected)
                test_error <= 1'b1;
        end
    end

endmodule