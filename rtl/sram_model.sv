//============================================================
// SRAM Model
//
// Behavioural SRAM used as the memory under test.
//
//  * Synchronous write, asynchronous (combinational) read.
//  * Contents are NOT reset: the March algorithm itself
//    initialises every cell in S0 before any read relies on
//    it (the paper excludes SRAM-initialisation checking from
//    the BIST scope). Un-written cells are X in simulation and
//    the data comparator treats X as a mismatch.
//  * Read-during-write: the read port is asynchronous, so a
//    read in the same cycle as a write to the same address
//    returns the OLD value (the new value appears after the
//    clock edge). The March controller never reads and writes
//    in the same cycle.
//
// Verification-only ports (not part of a real SRAM):
//  * fault_write_*   : lets the fault injector alter a cell
//                      other than the one being accessed
//                      (coupling / disturb faults).
//  * victim_read_*   : reads the victim cell's current content.
//  * aggr_read_*     : reads the aggressor cell's current content.
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
    // Fault-injection write (verification-only)
    //--------------------------------------------------------

    input logic                  fault_write_en,
    input logic [ADDR_WIDTH-1:0] fault_write_addr,
    input logic [DATA_WIDTH-1:0] fault_write_data,

    //--------------------------------------------------------
    // Victim-cell read (verification-only)
    //--------------------------------------------------------

    input logic [ADDR_WIDTH-1:0] victim_read_addr,
    output logic [DATA_WIDTH-1:0] victim_read_data,

    //--------------------------------------------------------
    // Aggressor-cell read (verification-only)
    //--------------------------------------------------------

    input logic [ADDR_WIDTH-1:0] aggr_read_addr,
    output logic [DATA_WIDTH-1:0] aggr_read_data
);

    localparam int DEPTH = (1 << ADDR_WIDTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    //--------------------------------------------------------
    // Synchronous write
    // (a fault write to the same address overrides a normal
    //  write, because it is applied last)
    //--------------------------------------------------------

    always_ff @(posedge clk) begin

        if (write_en)
            mem[write_addr] <= write_data;

        if (fault_write_en)
            mem[fault_write_addr] <= fault_write_data;

    end

    //--------------------------------------------------------
    // Asynchronous reads
    //--------------------------------------------------------

    always_comb begin

        read_data        = mem[read_addr];
        victim_read_data = mem[victim_read_addr];
        aggr_read_data   = mem[aggr_read_addr];

    end

endmodule
