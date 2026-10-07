//============================================================
// Address Generator
//
// Paper-aligned address generator.
//
// SRAM address interface shown in Fig. 3:
//     sram_addr[7:0]
//
// Generates ascending and descending memory addresses
// required by March mSR+.
//============================================================

module address_generator #(
    parameter int ADDR_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  reset,

    input  logic                  start,

    input  logic                  direction_up,
    input  logic                  restart_direction_up,

    input  logic                  cell_complete,
    input  logic                  address_restart,

    output logic [ADDR_WIDTH-1:0] addr,
    output logic                  last_addr
);

    //--------------------------------------------------------
    // Maximum address
    //--------------------------------------------------------

    localparam logic [ADDR_WIDTH-1:0] MAX_ADDR =
        {ADDR_WIDTH{1'b1}};


    //--------------------------------------------------------
    // Address register
    //--------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin

            addr <= '0;

        end

        else if (start) begin

            //------------------------------------------------
            // Initial March element S0 is ascending
            //------------------------------------------------

            if (direction_up)
                addr <= '0;

            else
                addr <= MAX_ADDR;

        end

        else if (address_restart) begin

            //------------------------------------------------
            // Restart address for next March element
            //------------------------------------------------

            if (restart_direction_up)
                addr <= '0;

            else
                addr <= MAX_ADDR;

        end

        else if (cell_complete) begin

            //------------------------------------------------
            // Ascending traversal
            //------------------------------------------------

            if (direction_up) begin

                if (addr != MAX_ADDR)
                    addr <= addr + 1'b1;

            end

            //------------------------------------------------
            // Descending traversal
            //------------------------------------------------

            else begin

                if (addr != '0)
                    addr <= addr - 1'b1;

            end

        end

    end


    //--------------------------------------------------------
    // Final address detection
    //--------------------------------------------------------

    always_comb begin

        if (direction_up)
            last_addr = (addr == MAX_ADDR);

        else
            last_addr = (addr == '0);

    end

endmodule