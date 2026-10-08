module fault_logger #(
    parameter ADDR_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  reset,

    // Error detected by comparator
    input  logic                  compare_error,

    // Current SRAM address
    input  logic [ADDR_WIDTH-1:0] addr,

    // End of BIST
    input  logic                  test_done,

    // Logged information
    output logic [7:0]            error_count,
    output logic                  fault_detected,
    output logic [ADDR_WIDTH-1:0] fault_address
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            error_count   <= 8'd0;
            fault_detected <= 1'b0;
            fault_address <= '0;
        end
        else begin

            // Record a newly detected error
            if (compare_error) begin

                fault_detected <= 1'b1;

                // Saturate instead of overflowing
                if (error_count != 8'hFF)
                    error_count <= error_count + 1'b1;

                // Record address where error occurred
                fault_address <= addr;
            end

            // Keep logged information after test completion
            if (test_done) begin
                fault_detected <= fault_detected;
            end

        end
    end

endmodule