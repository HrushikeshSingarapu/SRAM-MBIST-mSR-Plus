//============================================================
// BIST Controller
// March mSR+ Controller
//
// March mSR+:
//
// S0  ↑ (w0)
// S1  ↑ (w1)
// S2  ↑ (r1, w0)
// S3  ↑ (r0)
// S4  ↑ (r0)
// S5  ↑ (r0, w1)
// S6  ↑ (r1, w1)
// S7  ↑ (r1, w0, w1)
// S8  ↓ (r1, w0)
// S9  ↓ (r0, w1)
// S10 ↓ (r1)
// S11 ↓ (r1)
// S12 ↓ (r1, w0, r0)
//
// Total = 22N memory operations
//============================================================

module bist_controller (

    input  logic clk,
    input  logic rst,
    input  logic start,

    // Address generator status
    input  logic last_addr,

    // BIST status
    output logic busy,
    output logic done,

    // Current address direction
    // 1 = ascending
    // 0 = descending
    output logic direction_up,

    // Direction for next March element after restart
    output logic restart_direction_up,

    // Current-address operation completion
    output logic cell_complete,

    // Current March element completion
    output logic step_complete,

    // Restart address generator
    output logic address_restart,

    // Current March element
    // 0 = S0 ... 12 = S12
    output logic [3:0] march_step,

    // Current operation inside March element
    output logic [1:0] operation_index
);

    //--------------------------------------------------------
    // FSM states
    //--------------------------------------------------------

    typedef enum logic [3:0] {

        S_IDLE = 4'd0,

        S0     = 4'd1,
        S1     = 4'd2,
        S2     = 4'd3,
        S3     = 4'd4,
        S4     = 4'd5,
        S5     = 4'd6,
        S6     = 4'd7,
        S7     = 4'd8,
        S8     = 4'd9,
        S9     = 4'd10,
        S10    = 4'd11,
        S11    = 4'd12,
        S12    = 4'd13,

        S_DONE = 4'd14

    } state_t;

    state_t state;
    state_t next_state;

    //--------------------------------------------------------
    // Operation index
    //--------------------------------------------------------

    logic [1:0] op_index;
    logic [1:0] max_op_index;

    //--------------------------------------------------------
    // Maximum operation index
    //--------------------------------------------------------

    always_comb begin

        case (state)

            S0:  max_op_index = 2'd0;
            S1:  max_op_index = 2'd0;

            S2:  max_op_index = 2'd1;

            S3:  max_op_index = 2'd0;
            S4:  max_op_index = 2'd0;

            S5:  max_op_index = 2'd1;
            S6:  max_op_index = 2'd1;

            S7:  max_op_index = 2'd2;

            S8:  max_op_index = 2'd1;
            S9:  max_op_index = 2'd1;

            S10: max_op_index = 2'd0;
            S11: max_op_index = 2'd0;

            S12: max_op_index = 2'd2;

            default:
                max_op_index = 2'd0;

        endcase

    end

    //--------------------------------------------------------
    // State and operation registers
    //--------------------------------------------------------

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            state    <= S_IDLE;
            op_index <= 2'd0;

        end

        else begin

            state <= next_state;

            if ((state == S_IDLE) || (state == S_DONE)) begin

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
    // Next state logic
    //--------------------------------------------------------

    always_comb begin

        next_state = state;

        case (state)

            S_IDLE: begin

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
                    next_state = S_DONE;

            end

            S_DONE: begin

                next_state = S_IDLE;

            end

            default: begin

                next_state = S_IDLE;

            end

        endcase

    end

    //--------------------------------------------------------
    // Output logic
    //--------------------------------------------------------

    always_comb begin

        busy                 = 1'b0;
        done                 = 1'b0;

        direction_up         = 1'b1;
        restart_direction_up = 1'b1;

        cell_complete        = 1'b0;
        step_complete        = 1'b0;
        address_restart      = 1'b0;

        march_step           = 4'd0;
        operation_index      = op_index;

        case (state)

            //------------------------------------------------
            // Active March states
            //------------------------------------------------

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
                // Current direction
                //------------------------------------------------

                if (state <= S7)
                    direction_up = 1'b1;
                else
                    direction_up = 1'b0;

                //------------------------------------------------
                // Direction for next March element
                //------------------------------------------------

                // S0..S6  -> next element S1..S7 is ascending : restart at 0
                // S7..S11 -> next element S8..S12 is descending: restart at MAX
                // S12     -> test ends; the next run starts at S0 (ascending),
                //            so the address generator must be left at 0.
                //            (Previously S12 left the address at MAX, so a
                //             second run without reset started S0 at MAX and
                //             covered only one address.)

                if ((state <= S6) || (state == S12))
                    restart_direction_up = 1'b1;
                else
                    restart_direction_up = 1'b0;

                //------------------------------------------------
                // Last operation at current address
                //------------------------------------------------

                if (op_index == max_op_index)
                    cell_complete = 1'b1;

                //------------------------------------------------
                // Last operation at last address
                //------------------------------------------------

                if ((op_index == max_op_index) && last_addr) begin

                    step_complete   = 1'b1;
                    address_restart = 1'b1;

                end

            end

            //------------------------------------------------
            // DONE
            //------------------------------------------------

            S_DONE: begin

                busy = 1'b0;
                done = 1'b1;

            end

            default: begin

                busy = 1'b0;
                done = 1'b0;

            end

        endcase

    end

endmodule