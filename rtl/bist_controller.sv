//============================================================
// BIST Controller
//
// March mSR+ controller based on the base paper:
//
// M.-Y. Lin, W.-K. Chiang, and C.-H. Wang,
// "Enhancing Memory BIST With an Optimized RTL-BIST IP Core:
// A Low-Power, High-Fault-Coverage Approach."
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
//
// Complexity = 22N
//============================================================

module bist_controller (

    input  logic clk,
    input  logic reset,
    input  logic start,

    // Address generator status
    input  logic last_addr,

    // Controller status
    output logic test_done,
    output logic busy,

    // March traversal
    output logic direction_up,
    output logic restart_direction_up,

    // Address control
    output logic cell_complete,
    output logic step_complete,
    output logic address_restart,

    // Current March element
    output logic [3:0] march_step,

    // Current operation within March element
    output logic [1:0] operation_index

);

    //--------------------------------------------------------
    // FSM states
    //--------------------------------------------------------

    typedef enum logic [3:0] {

        IDLE = 4'd0,

        S0   = 4'd1,
        S1   = 4'd2,
        S2   = 4'd3,
        S3   = 4'd4,
        S4   = 4'd5,
        S5   = 4'd6,
        S6   = 4'd7,
        S7   = 4'd8,
        S8   = 4'd9,
        S9   = 4'd10,
        S10  = 4'd11,
        S11  = 4'd12,
        S12  = 4'd13,

        DONE = 4'd14

    } state_t;

    state_t state;
    state_t next_state;


    //--------------------------------------------------------
    // Operation index
    //--------------------------------------------------------

    logic [1:0] op_index;
    logic [1:0] max_op_index;


    //--------------------------------------------------------
    // Number of operations in each March element
    //--------------------------------------------------------

    always_comb begin

        case (state)

            S0:  max_op_index = 2'd0;   // w0
            S1:  max_op_index = 2'd0;   // w1

            S2:  max_op_index = 2'd1;   // r1,w0

            S3:  max_op_index = 2'd0;   // r0
            S4:  max_op_index = 2'd0;   // r0

            S5:  max_op_index = 2'd1;   // r0,w1
            S6:  max_op_index = 2'd1;   // r1,w1

            S7:  max_op_index = 2'd2;   // r1,w0,w1

            S8:  max_op_index = 2'd1;   // r1,w0
            S9:  max_op_index = 2'd1;   // r0,w1

            S10: max_op_index = 2'd0;   // r1
            S11: max_op_index = 2'd0;   // r1

            S12: max_op_index = 2'd2;   // r1,w0,r0

            default:
                max_op_index = 2'd0;

        endcase

    end


    //--------------------------------------------------------
    // State and operation registers
    //--------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin

            state    <= IDLE;
            op_index <= 2'd0;

        end

        else begin

            state <= next_state;

            if (state == IDLE) begin

                op_index <= 2'd0;

            end

            else if (state == DONE) begin

                op_index <= 2'd0;

            end

            else if (op_index < max_op_index) begin

                op_index <= op_index + 2'd1;

            end

            else begin

                op_index <= 2'd0;

            end

        end

    end


    //--------------------------------------------------------
    // Next-state logic
    //--------------------------------------------------------

    always_comb begin

        next_state = state;

        case (state)

            IDLE: begin

                if (start)
                    next_state = S0;

            end

            S0: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S1;

            end

            S1: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S2;

            end

            S2: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S3;

            end

            S3: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S4;

            end

            S4: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S5;

            end

            S5: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S6;

            end

            S6: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S7;

            end

            S7: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S8;

            end

            S8: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S9;

            end

            S9: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S10;

            end

            S10: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S11;

            end

            S11: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = S12;

            end

            S12: begin

                if ((op_index == max_op_index) && last_addr)
                    next_state = DONE;

            end

            DONE: begin

                next_state = IDLE;

            end

            default: begin

                next_state = IDLE;

            end

        endcase

    end


    //--------------------------------------------------------
    // Output logic
    //--------------------------------------------------------

    always_comb begin

        busy                 = 1'b0;
        test_done            = 1'b0;

        direction_up         = 1'b1;
        restart_direction_up = 1'b1;

        cell_complete        = 1'b0;
        step_complete        = 1'b0;
        address_restart      = 1'b0;

        march_step           = 4'd0;
        operation_index      = op_index;


        case (state)

            S0, S1, S2, S3, S4, S5, S6,
            S7, S8, S9, S10, S11, S12: begin

                busy = 1'b1;


                //------------------------------------------------
                // March element number
                //------------------------------------------------

                case (state)

                    S0:  march_step = 4'd0;
                    S1:  march_step = 4'd1;
                    S2:  march_step = 4'd2;
                    S3:  march_step = 4'd3;
                    S4:  march_step = 4'd4;
                    S5:  march_step = 4'd5;
                    S6:  march_step = 4'd6;
                    S7:  march_step = 4'd7;
                    S8:  march_step = 4'd8;
                    S9:  march_step = 4'd9;
                    S10: march_step = 4'd10;
                    S11: march_step = 4'd11;
                    S12: march_step = 4'd12;

                    default:
                        march_step = 4'd0;

                endcase


                //------------------------------------------------
                // Current traversal direction
                //------------------------------------------------

                if (state <= S7)
                    direction_up = 1'b1;
                else
                    direction_up = 1'b0;


                //------------------------------------------------
                // Direction of next March element
                //------------------------------------------------

                if (state <= S6)
                    restart_direction_up = 1'b1;
                else
                    restart_direction_up = 1'b0;


                //------------------------------------------------
                // Last operation at current address
                //------------------------------------------------

                if (op_index == max_op_index)
                    cell_complete = 1'b1;


                //------------------------------------------------
                // Last operation at final address
                //------------------------------------------------

                if ((op_index == max_op_index) && last_addr) begin

                    step_complete   = 1'b1;
                    address_restart = 1'b1;

                end

            end


            DONE: begin

                busy      = 1'b0;
                test_done = 1'b1;

            end


            default: begin

                busy      = 1'b0;
                test_done = 1'b0;

            end

        endcase

    end

endmodule