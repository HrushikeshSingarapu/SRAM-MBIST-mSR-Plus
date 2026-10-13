//============================================================
// Address Generator
//============================================================

module address_generator #(
    parameter int ADDR_WIDTH = 4
)(
    input logic clk,
    input logic rst,

    // Current March direction
    input logic direction_up,

    // Direction for next March element
    input logic restart_direction_up,

    // Current address completed
    input logic cell_complete,

    // Restart at beginning of next March element
    input logic address_restart,

    output logic [ADDR_WIDTH-1:0] addr,

    // 1 when current address is last address
    // for current traversal direction
    output logic last_addr
);

    //--------------------------------------------------------
    // Last-address detection
    //--------------------------------------------------------

    always_comb begin

        if (direction_up)
            last_addr = (addr == {ADDR_WIDTH{1'b1}});

        else
            last_addr = (addr == {ADDR_WIDTH{1'b0}});

    end

    //--------------------------------------------------------
    // Address register
    //--------------------------------------------------------

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            addr <= {ADDR_WIDTH{1'b0}};

        end

        else begin

            //------------------------------------------------
            // Restart for next March element
            //------------------------------------------------

            if (address_restart) begin

                if (restart_direction_up)
                    addr <= {ADDR_WIDTH{1'b0}};

                else
                    addr <= {ADDR_WIDTH{1'b1}};

            end

            //------------------------------------------------
            // Move to next address
            //------------------------------------------------

            else if (cell_complete) begin

                if (direction_up) begin

                    if (!last_addr)
                        addr <= addr + 1'b1;

                end

                else begin

                    if (!last_addr)
                        addr <= addr - 1'b1;

                end

            end

        end

    end

endmodule
