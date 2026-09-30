//============================================================
// MBIST Address Generator
//
// Common block for all March algorithms
//
// direction_up = 1'b1 : ascending
// direction_up = 1'b0 : descending
//
// restart_direction_up gives the direction of the NEXT
// March element when address_restart is asserted.
//============================================================

module address_generator #(
    parameter int ADDR_WIDTH = 4
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  start,

    // Current traversal direction
    input  logic                  direction_up,

    // Direction for next March element
    input  logic                  restart_direction_up,

    // Controller status
    input  logic                  cell_complete,
    input  logic                  address_restart,

    // SRAM address
    output logic [ADDR_WIDTH-1:0] addr,

    // Last address of current traversal
    output logic                  last_addr
);

    localparam logic [ADDR_WIDTH-1:0] MAX_ADDR =
                                      {ADDR_WIDTH{1'b1}};


    //--------------------------------------------------------
    // Address register
    //--------------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            addr <= '0;

        end

        else if (start) begin

            // First March element

            if (direction_up)
                addr <= '0;
            else
                addr <= MAX_ADDR;

        end

        else if (address_restart) begin

            // Start the NEXT March element.
            //
            // IMPORTANT:
            // Use restart_direction_up, not direction_up.

            if (restart_direction_up)
                addr <= '0;
            else
                addr <= MAX_ADDR;

        end

        else if (cell_complete) begin

            // Move to next memory address.

            if (direction_up) begin

                if (addr != MAX_ADDR)
                    addr <= addr + 1'b1;

            end

            else begin

                if (addr != '0)
                    addr <= addr - 1'b1;

            end

        end

    end


    //--------------------------------------------------------
    // Last address detection
    //--------------------------------------------------------

    always_comb begin

        if (direction_up)
            last_addr = (addr == MAX_ADDR);

        else
            last_addr = (addr == '0);

    end

endmodule