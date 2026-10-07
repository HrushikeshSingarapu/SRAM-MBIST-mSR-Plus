//============================================================
// Pattern Generator
//
// Generates the data patterns required by March mSR+.
//
// Paper:
//     Pattern_Generator / pattern_gen
//
// SRAM data width shown in Fig. 3:
//     32 bits
//
// March mSR+:
// S0  ↑ (w0)
// S1  ↑ (w1)
// S2  ↑ (r1,w0)
// S3  ↑ (r0)
// S4  ↑ (r0)
// S5  ↑ (r0,w1)
// S6  ↑ (r1,w1)
// S7  ↑ (r1,w0,w1)
// S8  ↓ (r1,w0)
// S9  ↓ (r0,w1)
// S10 ↓ (r1)
// S11 ↓ (r1)
// S12 ↓ (r1,w0,r0)
//============================================================

module pattern_generator #(
    parameter int DATA_WIDTH = 32
)(
    input  logic [3:0] march_step,
    input  logic [1:0] operation_index,

    output logic                  mem_read,
    output logic                  mem_write,

    output logic [DATA_WIDTH-1:0] write_data,
    output logic [DATA_WIDTH-1:0] expected_data
);

    //--------------------------------------------------------
    // March data patterns
    //--------------------------------------------------------

    localparam logic [DATA_WIDTH-1:0] DATA_ZERO =
        {DATA_WIDTH{1'b0}};

    localparam logic [DATA_WIDTH-1:0] DATA_ONE =
        {DATA_WIDTH{1'b1}};


    //--------------------------------------------------------
    // Pattern generation
    //--------------------------------------------------------

    always_comb begin

        mem_read      = 1'b0;
        mem_write     = 1'b0;

        write_data    = DATA_ZERO;
        expected_data = DATA_ZERO;


        case (march_step)

            //------------------------------------------------
            // S0 : ↑ (w0)
            //------------------------------------------------

            4'd0: begin

                mem_write = 1'b1;
                write_data = DATA_ZERO;

            end


            //------------------------------------------------
            // S1 : ↑ (w1)
            //------------------------------------------------

            4'd1: begin

                mem_write = 1'b1;
                write_data = DATA_ONE;

            end


            //------------------------------------------------
            // S2 : ↑ (r1,w0)
            //------------------------------------------------

            4'd2: begin

                case (operation_index)

                    2'd0: begin

                        mem_read = 1'b1;
                        expected_data = DATA_ONE;

                    end

                    2'd1: begin

                        mem_write = 1'b1;
                        write_data = DATA_ZERO;

                    end

                    default: begin

                        mem_read  = 1'b0;
                        mem_write = 1'b0;

                    end

                endcase

            end


            //------------------------------------------------
            // S3 : ↑ (r0)
            //------------------------------------------------

            4'd3: begin

                mem_read = 1'b1;
                expected_data = DATA_ZERO;

            end


            //------------------------------------------------
            // S4 : ↑ (r0)
            //------------------------------------------------

            4'd4: begin

                mem_read = 1'b1;
                expected_data = DATA_ZERO;

            end


            //------------------------------------------------
            // S5 : ↑ (r0,w1)
            //------------------------------------------------

            4'd5: begin

                case (operation_index)

                    2'd0: begin

                        mem_read = 1'b1;
                        expected_data = DATA_ZERO;

                    end

                    2'd1: begin

                        mem_write = 1'b1;
                        write_data = DATA_ONE;

                    end

                    default: begin

                        mem_read  = 1'b0;
                        mem_write = 1'b0;

                    end

                endcase

            end


            //------------------------------------------------
            // S6 : ↑ (r1,w1)
            //------------------------------------------------

            4'd6: begin

                case (operation_index)

                    2'd0: begin

                        mem_read = 1'b1;
                        expected_data = DATA_ONE;

                    end

                    2'd1: begin

                        mem_write = 1'b1;
                        write_data = DATA_ONE;

                    end

                    default: begin

                        mem_read  = 1'b0;
                        mem_write = 1'b0;

                    end

                endcase

            end


            //------------------------------------------------
            // S7 : ↑ (r1,w0,w1)
            //------------------------------------------------

            4'd7: begin

                case (operation_index)

                    2'd0: begin

                        mem_read = 1'b1;
                        expected_data = DATA_ONE;

                    end

                    2'd1: begin

                        mem_write = 1'b1;
                        write_data = DATA_ZERO;

                    end

                    2'd2: begin

                        mem_write = 1'b1;
                        write_data = DATA_ONE;

                    end

                    default: begin

                        mem_read  = 1'b0;
                        mem_write = 1'b0;

                    end

                endcase

            end


            //------------------------------------------------
            // S8 : ↓ (r1,w0)
            //------------------------------------------------

            4'd8: begin

                case (operation_index)

                    2'd0: begin

                        mem_read = 1'b1;
                        expected_data = DATA_ONE;

                    end

                    2'd1: begin

                        mem_write = 1'b1;
                        write_data = DATA_ZERO;

                    end

                    default: begin

                        mem_read  = 1'b0;
                        mem_write = 1'b0;

                    end

                endcase

            end


            //------------------------------------------------
            // S9 : ↓ (r0,w1)
            //------------------------------------------------

            4'd9: begin

                case (operation_index)

                    2'd0: begin

                        mem_read = 1'b1;
                        expected_data = DATA_ZERO;

                    end

                    2'd1: begin

                        mem_write = 1'b1;
                        write_data = DATA_ONE;

                    end

                    default: begin

                        mem_read  = 1'b0;
                        mem_write = 1'b0;

                    end

                endcase

            end


            //------------------------------------------------
            // S10 : ↓ (r1)
            //------------------------------------------------

            4'd10: begin

                mem_read = 1'b1;
                expected_data = DATA_ONE;

            end


            //------------------------------------------------
            // S11 : ↓ (r1)
            //------------------------------------------------

            4'd11: begin

                mem_read = 1'b1;
                expected_data = DATA_ONE;

            end


            //------------------------------------------------
            // S12 : ↓ (r1,w0,r0)
            //------------------------------------------------

            4'd12: begin

                case (operation_index)

                    2'd0: begin

                        mem_read = 1'b1;
                        expected_data = DATA_ONE;

                    end

                    2'd1: begin

                        mem_write = 1'b1;
                        write_data = DATA_ZERO;

                    end

                    2'd2: begin

                        mem_read = 1'b1;
                        expected_data = DATA_ZERO;

                    end

                    default: begin

                        mem_read  = 1'b0;
                        mem_write = 1'b0;

                    end

                endcase

            end


            //------------------------------------------------
            // Invalid / idle
            //------------------------------------------------

            default: begin

                mem_read      = 1'b0;
                mem_write     = 1'b0;
                write_data    = DATA_ZERO;
                expected_data = DATA_ZERO;

            end

        endcase

    end

endmodule