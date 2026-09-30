//============================================================
// SRAM Model
//
// Common memory model for all March algorithms
//
// Write : synchronous
// Read  : asynchronous
//============================================================

module sram_model #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst,

    input  logic                  mem_read,
    input  logic                  mem_write,

    input  logic [ADDR_WIDTH-1:0] addr,

    input  logic [DATA_WIDTH-1:0] write_data,

    output logic [DATA_WIDTH-1:0] read_data
);

    localparam int DEPTH = (1 << ADDR_WIDTH);


    //--------------------------------------------------------
    // SRAM array
    //--------------------------------------------------------

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];


    //--------------------------------------------------------
    // WRITE
    //--------------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin
            // No memory initialization.
        end

        else begin

            if (mem_write) begin
                mem[addr] <= write_data;
            end

        end

    end


    //--------------------------------------------------------
    // READ
    //--------------------------------------------------------

    always_comb begin

        if (mem_read)
            read_data = mem[addr];

        else
            read_data = '0;

    end

endmodule
