//============================================================
// Test Mode Control
//
// Selects MBIST control signals when test mode is active.
//
// For simulation, the control signals are combinational so
// that the March operation, address and SRAM access remain
// aligned within the same cycle.
//============================================================

module test_mode_control (
    input  logic clk,
    input  logic reset,

    input  logic test_mode,

    input  logic bist_mem_read,
    input  logic bist_mem_write,

    output logic sram_mode,
    output logic addr_en,
    output logic mem_read,
    output logic mem_write
);

    always_comb begin

        sram_mode = 1'b0;
        addr_en   = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;

        if (test_mode && !reset) begin

            sram_mode = 1'b1;
            addr_en   = 1'b1;

            mem_read  = bist_mem_read;
            mem_write = bist_mem_write;

        end

    end

endmodule
