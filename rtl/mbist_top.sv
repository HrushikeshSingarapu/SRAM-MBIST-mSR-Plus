//============================================================
// SRAM MBIST Top Module
//
// Integrates the six verified MBIST blocks:
//
//   1. MBIST Controller
//   2. Address Generator
//   3. Pattern Controller
//   4. SRAM Model
//   5. Comparator
//   6. Status Logic
//
// Algorithm:
//   March mSR+
//
//============================================================

module mbist_top #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 8
)(
    input  logic clk,
    input  logic rst,
    input  logic start,

    output logic busy,
    output logic done,
    output logic pass,
    output logic fail,
    output logic fault
);

    //--------------------------------------------------------
    // Controller signals
    //--------------------------------------------------------

    logic controller_busy;
    logic controller_done;

    logic direction_up;
    logic restart_direction_up;

    logic cell_complete;
    logic step_complete;
    logic address_restart;

    logic [3:0] march_step;
    logic [1:0] operation_index;


    //--------------------------------------------------------
    // Address generator signals
    //--------------------------------------------------------

    logic [ADDR_WIDTH-1:0] addr;
    logic last_addr;


    //--------------------------------------------------------
    // Pattern controller signals
    //--------------------------------------------------------

    logic mem_read;
    logic mem_write;

    logic [DATA_WIDTH-1:0] write_data;
    logic [DATA_WIDTH-1:0] expected_data;


    //--------------------------------------------------------
    // SRAM signals
    //--------------------------------------------------------

    logic [DATA_WIDTH-1:0] read_data;


    //--------------------------------------------------------
    // Comparator signal
    //--------------------------------------------------------

    logic mismatch;


    //--------------------------------------------------------
    // MBIST CONTROLLER
    //--------------------------------------------------------

    mbist_controller controller_inst (

        .clk                  (clk),
        .rst                  (rst),
        .start                (start),

        .last_addr            (last_addr),

        .busy                 (controller_busy),
        .done                 (controller_done),

        .direction_up         (direction_up),
        .restart_direction_up (restart_direction_up),

        .cell_complete        (cell_complete),
        .step_complete        (step_complete),
        .address_restart      (address_restart),

        .march_step           (march_step),
        .operation_index      (operation_index)

    );


    //--------------------------------------------------------
    // ADDRESS GENERATOR
    //--------------------------------------------------------

    address_generator #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) address_generator_inst (

        .clk                  (clk),
        .rst                  (rst),
        .start                (start),

        .direction_up         (direction_up),
        .restart_direction_up (restart_direction_up),

        .cell_complete        (cell_complete),
        .address_restart      (address_restart),

        .addr                 (addr),
        .last_addr            (last_addr)

    );


    //--------------------------------------------------------
    // PATTERN CONTROLLER
    //--------------------------------------------------------

    pattern_controller #(
        .DATA_WIDTH(DATA_WIDTH)
    ) pattern_controller_inst (

        .march_step      (march_step),
        .operation_index (operation_index),

        .mem_read        (mem_read),
        .mem_write       (mem_write),

        .write_data      (write_data),
        .expected_data   (expected_data)

    );


    //--------------------------------------------------------
    // SRAM MODEL
    //--------------------------------------------------------

    sram_model #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) sram_inst (

        .clk       (clk),
        .rst       (rst),

        .mem_read  (mem_read),
        .mem_write (mem_write),

        .addr      (addr),

        .write_data(write_data),

        .read_data (read_data)

    );


    //--------------------------------------------------------
    // COMPARATOR
    //--------------------------------------------------------

    comparator #(
        .DATA_WIDTH(DATA_WIDTH)
    ) comparator_inst (

        .expected_data (expected_data),
        .actual_data   (read_data),

        .compare_en    (mem_read),

        .mismatch      (mismatch)

    );


    //--------------------------------------------------------
    // STATUS LOGIC
    //--------------------------------------------------------

    status_logic status_inst (

        .clk             (clk),
        .rst             (rst),
        .start           (start),

        .mismatch        (mismatch),

        .controller_busy (controller_busy),
        .controller_done (controller_done),

        .fault           (fault),
        .done            (done),

        .busy            (busy),
        .pass            (pass),
        .fail            (fail)

    );

endmodule