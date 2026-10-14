//============================================================
// Fault Injection
//
// Verification-oriented behavioral fault model.
//
// Fault types:
//
// 0  SAF
// 1  TF
// 2  CFID
// 3  CFDRD
// 4  CFIN
// 5  RDF
// 6  DRDF
// 7  IRF
// 8  CFTR
// 9  CFWD
// 10 WDF
//
// This is a project-level behavioral model based on the
// fault models described in the reference paper.
//============================================================

module fault_injection #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 8
)(
    input logic clk,
    input logic rst,

    //--------------------------------------------------------
    // Current memory operation
    //--------------------------------------------------------

    input logic                  mem_read,
    input logic                  mem_write,

    input logic [ADDR_WIDTH-1:0] addr,

    input logic [DATA_WIDTH-1:0] normal_read_data,
    input logic [DATA_WIDTH-1:0] write_data,

    //--------------------------------------------------------
    // Victim cell data
    //--------------------------------------------------------

    input logic [DATA_WIDTH-1:0] victim_data,

    //--------------------------------------------------------
    // Fault configuration
    //--------------------------------------------------------

    input logic                  fault_enable,
    input logic [3:0]            fault_type,

    input logic [ADDR_WIDTH-1:0] fault_address,
    input logic [ADDR_WIDTH-1:0] aggressor_address,

    input logic                  stuck_at_value,

    //--------------------------------------------------------
    // Faulty current operation
    //--------------------------------------------------------

    output logic [DATA_WIDTH-1:0] faulty_read_data,
    output logic [DATA_WIDTH-1:0] faulty_write_data,

    //--------------------------------------------------------
    // Fault-induced victim write
    //--------------------------------------------------------

    output logic                  fault_write_en,
    output logic [ADDR_WIDTH-1:0] fault_write_addr,
    output logic [DATA_WIDTH-1:0] fault_write_data
);

    //--------------------------------------------------------
    // Fault IDs
    //--------------------------------------------------------

    localparam logic [3:0] SAF   = 4'd0;
    localparam logic [3:0] TF    = 4'd1;
    localparam logic [3:0] CFID  = 4'd2;
    localparam logic [3:0] CFDRD = 4'd3;
    localparam logic [3:0] CFIN  = 4'd4;
    localparam logic [3:0] RDF   = 4'd5;
    localparam logic [3:0] DRDF  = 4'd6;
    localparam logic [3:0] IRF   = 4'd7;
    localparam logic [3:0] CFTR  = 4'd8;
    localparam logic [3:0] CFWD  = 4'd9;
    localparam logic [3:0] WDF   = 4'd10;

    localparam logic [DATA_WIDTH-1:0] DATA_ZERO =
        {DATA_WIDTH{1'b0}};

    localparam logic [DATA_WIDTH-1:0] DATA_ONE =
        {DATA_WIDTH{1'b1}};

    //--------------------------------------------------------
    // History
    //--------------------------------------------------------

    logic [DATA_WIDTH-1:0] previous_write_data;
    logic                  previous_write_valid;

    logic [ADDR_WIDTH-1:0] previous_read_addr;
    logic                  previous_read_valid;

    //--------------------------------------------------------
    // History registers
    //--------------------------------------------------------

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            previous_write_data  <= DATA_ZERO;
            previous_write_valid <= 1'b0;

            previous_read_addr   <= '0;
            previous_read_valid  <= 1'b0;

        end

        else begin

            if (mem_write) begin

                previous_write_data  <= write_data;
                previous_write_valid <= 1'b1;

            end

            if (mem_read) begin

                previous_read_addr  <= addr;
                previous_read_valid <= 1'b1;

            end

        end

    end

    //--------------------------------------------------------
    // Fault behavior
    //--------------------------------------------------------

    always_comb begin

        //----------------------------------------------------
        // Defaults
        //----------------------------------------------------

        faulty_read_data  = normal_read_data;
        faulty_write_data = write_data;

        fault_write_en    = 1'b0;
        fault_write_addr  = fault_address;
        fault_write_data  = victim_data;

        //----------------------------------------------------
        // Fault disabled
        //----------------------------------------------------

        if (!fault_enable) begin

            faulty_read_data  = normal_read_data;
            faulty_write_data = write_data;

        end

        //----------------------------------------------------
        // Fault enabled
        //----------------------------------------------------

        else begin

            case (fault_type)

                //------------------------------------------------
                // SAF
                //------------------------------------------------

                SAF: begin

                    if (addr == fault_address) begin

                        faulty_read_data =
                            {DATA_WIDTH{stuck_at_value}};

                        faulty_write_data =
                            {DATA_WIDTH{stuck_at_value}};

                    end

                end

                //------------------------------------------------
                // TF
                //------------------------------------------------

                TF: begin

                    if (addr == fault_address) begin

                        if (write_data != normal_read_data)
                            faulty_write_data = normal_read_data;

                    end

                end

                //------------------------------------------------
                // CFID
                //------------------------------------------------

                CFID: begin

                    if (mem_write &&
                        (addr == aggressor_address)) begin

                        fault_write_en   = 1'b1;
                        fault_write_addr = fault_address;
                        fault_write_data = ~victim_data;

                    end

                end

                //------------------------------------------------
                // CFDRD
                //------------------------------------------------

                CFDRD: begin

                    if (mem_read &&
                        (addr == aggressor_address)) begin

                        fault_write_en   = 1'b1;
                        fault_write_addr = fault_address;
                        fault_write_data = ~victim_data;

                    end

                end

                //------------------------------------------------
                // CFIN
                //------------------------------------------------

                CFIN: begin

                    if (mem_write &&
                        (addr == aggressor_address)) begin

                        fault_write_en   = 1'b1;
                        fault_write_addr = fault_address;
                        fault_write_data = ~victim_data;

                    end

                end

                //------------------------------------------------
                // RDF
                //------------------------------------------------

                RDF: begin

                    if (mem_read &&
                        (addr == fault_address)) begin

                        faulty_read_data = ~normal_read_data;

                    end

                end

                //------------------------------------------------
                // DRDF
                //------------------------------------------------

                DRDF: begin

                    if (mem_read &&
                        previous_read_valid &&
                        (previous_read_addr == addr) &&
                        (addr == fault_address)) begin

                        faulty_read_data = ~normal_read_data;

                    end

                end

                //------------------------------------------------
                // IRF
                //------------------------------------------------

                IRF: begin

                    if (mem_read &&
                        previous_write_valid &&
                        (addr == fault_address)) begin

                        faulty_read_data = ~normal_read_data;

                    end

                end

                //------------------------------------------------
                // CFTR
                //------------------------------------------------

                CFTR: begin

                    if (mem_write &&
                        (addr == aggressor_address) &&
                        (write_data != normal_read_data)) begin

                        fault_write_en   = 1'b1;
                        fault_write_addr = fault_address;
                        fault_write_data = ~victim_data;

                    end

                end

                //------------------------------------------------
                // CFWD
                //------------------------------------------------

                CFWD: begin

                    if (mem_write &&
                        (addr == aggressor_address)) begin

                        fault_write_en   = 1'b1;
                        fault_write_addr = fault_address;

                        if (write_data == DATA_ZERO)
                            fault_write_data = DATA_ZERO;
                        else
                            fault_write_data = DATA_ONE;

                    end

                end

                //------------------------------------------------
                // WDF
                //------------------------------------------------

                WDF: begin

                    if (mem_write &&
                        (addr == fault_address)) begin

                        faulty_write_data = ~write_data;

                    end

                end

                default: begin

                    faulty_read_data  = normal_read_data;
                    faulty_write_data = write_data;

                end

            endcase

        end

    end

endmodule