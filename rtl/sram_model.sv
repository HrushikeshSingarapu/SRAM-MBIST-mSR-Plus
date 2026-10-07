//============================================================
// SRAM Model
//
// Simulation model for the SRAM connected to the RTL-BIST IP.
//
// Paper Fig. 3 interface:
//     sram_addr[7:0]
//     sram_read_data[31:0]
//     sram_write_data[31:0]
//
// This is a verification model, not one of the eight named
// RTL-BIST functional blocks in Fig. 3.
//============================================================

module sram_model #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  reset,

    input  logic                  mem_read,
    input  logic                  mem_write,

    input  logic [ADDR_WIDTH-1:0] sram_addr,

    input  logic [DATA_WIDTH-1:0] sram_write_data,

    output logic [DATA_WIDTH-1:0] sram_read_data
);

    localparam int DEPTH = (1 << ADDR_WIDTH);


    //--------------------------------------------------------
    // SRAM array
    //--------------------------------------------------------

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];


    //--------------------------------------------------------
    // Synchronous write
    //--------------------------------------------------------

    always_ff @(posedge clk) begin

        if (!reset) begin

            if (mem_write)
                mem[sram_addr] <= sram_write_data;

        end

    end


    //--------------------------------------------------------
    // Asynchronous read
    //--------------------------------------------------------

    always_comb begin

        if (mem_read)
            sram_read_data = mem[sram_addr];

        else
            sram_read_data = '0;

    end

endmodule