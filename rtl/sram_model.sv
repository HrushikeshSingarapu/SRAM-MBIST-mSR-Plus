//============================================================
// SRAM Model
//============================================================

module sram_model #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 8
)(
    input logic clk,

    //--------------------------------------------------------
    // Normal SRAM write
    //--------------------------------------------------------

    input logic                  write_en,
    input logic [ADDR_WIDTH-1:0] write_addr,
    input logic [DATA_WIDTH-1:0] write_data,

    //--------------------------------------------------------
    // Normal SRAM read
    //--------------------------------------------------------

    input logic [ADDR_WIDTH-1:0] read_addr,
    output logic [DATA_WIDTH-1:0] read_data,

    //--------------------------------------------------------
    // Fault-injection write
    //
    // Verification-only
    //--------------------------------------------------------

    input logic                  fault_write_en,
    input logic [ADDR_WIDTH-1:0] fault_write_addr,
    input logic [DATA_WIDTH-1:0] fault_write_data,

    //--------------------------------------------------------
    // Victim-cell read
    //
    // Verification-only
    //--------------------------------------------------------

    input logic [ADDR_WIDTH-1:0] victim_read_addr,
    output logic [DATA_WIDTH-1:0] victim_read_data
);

    localparam int DEPTH = (1 << ADDR_WIDTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    //--------------------------------------------------------
    // Synchronous write
    //--------------------------------------------------------

    always_ff @(posedge clk) begin

        if (write_en)
            mem[write_addr] <= write_data;

        if (fault_write_en)
            mem[fault_write_addr] <= fault_write_data;

    end

    //--------------------------------------------------------
    // Asynchronous normal read
    //--------------------------------------------------------

    always_comb begin

        read_data = mem[read_addr];

    end

    //--------------------------------------------------------
    // Asynchronous victim read
    //--------------------------------------------------------

    always_comb begin

        victim_read_data = mem[victim_read_addr];

    end

endmodule
