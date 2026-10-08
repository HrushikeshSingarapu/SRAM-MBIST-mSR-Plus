module test_mode_control (
    input  logic       clk,
    input  logic       reset,

    // Test-mode request
    input  logic       test_mode,

    // SRAM interface control
    input  logic       bist_mem_read,
    input  logic       bist_mem_write,

    output logic       sram_mode,
    output logic       addr_en,
    output logic       mem_read,
    output logic       mem_write
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sram_mode <= 1'b0;
            addr_en   <= 1'b0;
            mem_read  <= 1'b0;
            mem_write <= 1'b0;
        end
        else begin
            if (test_mode) begin
                // MBIST/test mode
                sram_mode <= 1'b1;
                addr_en   <= 1'b1;
                mem_read  <= bist_mem_read;
                mem_write <= bist_mem_write;
            end
            else begin
                // Normal functional mode
                sram_mode <= 1'b0;
                addr_en   <= 1'b0;
                mem_read  <= 1'b0;
                mem_write <= 1'b0;
            end
        end
    end

endmodule