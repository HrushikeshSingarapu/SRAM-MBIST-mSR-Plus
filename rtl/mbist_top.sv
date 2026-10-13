//============================================================
// MBIST TOP
//
// Complete SRAM MBIST integration
//
// March mSR+
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

module mbist_top #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst,
    input logic start,

    //--------------------------------------------------------
    // Fault injection configuration
    //--------------------------------------------------------

    input logic                  fault_enable,
    input logic [3:0]            fault_type,

    input logic [ADDR_WIDTH-1:0] fault_address,
    input logic [ADDR_WIDTH-1:0] aggressor_address,

    input logic                  stuck_at_value,

    //--------------------------------------------------------
    // Final BIST status
    //--------------------------------------------------------

    output logic busy,
    output logic done,
    output logic pass,
    output logic fail,

    //--------------------------------------------------------
    // Debug/status
    //--------------------------------------------------------

    output logic [ADDR_WIDTH-1:0] current_address,
    output logic [3:0]            march_step,
    output logic [1:0]            operation_index,
    output logic                  direction_up
);

    //--------------------------------------------------------
    // Controller signals
    //--------------------------------------------------------

    logic restart_direction_up;
    logic cell_complete;
    logic step_complete;
    logic address_restart;
    logic last_addr;

    //--------------------------------------------------------
    // Pattern generator signals
    //--------------------------------------------------------

    logic mem_read;
    logic mem_write;

    logic [DATA_WIDTH-1:0] write_data;
    logic [DATA_WIDTH-1:0] expected_data;

    //--------------------------------------------------------
    // SRAM signals
    //--------------------------------------------------------

    logic [DATA_WIDTH-1:0] normal_read_data;
    logic [DATA_WIDTH-1:0] victim_data;

    //--------------------------------------------------------
    // Fault injection signals
    //--------------------------------------------------------

    logic [DATA_WIDTH-1:0] faulty_read_data;
    logic [DATA_WIDTH-1:0] faulty_write_data;

    logic                  fault_write_en;
    logic [ADDR_WIDTH-1:0] fault_write_addr;
    logic [DATA_WIDTH-1:0] fault_write_data;

    //--------------------------------------------------------
    // Comparator signals
    //--------------------------------------------------------

    logic mismatch;

    //--------------------------------------------------------
    // Status
    //--------------------------------------------------------

    logic fault_detected;

    //--------------------------------------------------------
    // Address
    //--------------------------------------------------------

    logic [ADDR_WIDTH-1:0] addr;

    //--------------------------------------------------------
    // 1. BIST CONTROLLER
    //--------------------------------------------------------

    bist_controller bist_controller_inst (

        .clk(clk),
        .rst(rst),
        .start(start),

        .last_addr(last_addr),

        .busy(busy),
        .done(done),

        .direction_up(direction_up),
        .restart_direction_up(restart_direction_up),

        .cell_complete(cell_complete),
        .step_complete(step_complete),
        .address_restart(address_restart),

        .march_step(march_step),
        .operation_index(operation_index)

    );

    //--------------------------------------------------------
    // 2. ADDRESS GENERATOR
    //--------------------------------------------------------

    address_generator #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) address_generator_inst (

        .clk(clk),
        .rst(rst),

        .direction_up(direction_up),
        .restart_direction_up(restart_direction_up),

        .cell_complete(cell_complete),
        .address_restart(address_restart),

        .addr(addr),
        .last_addr(last_addr)

    );

    //--------------------------------------------------------
    // 3. PATTERN GENERATOR
    //--------------------------------------------------------

    pattern_generator #(
        .DATA_WIDTH(DATA_WIDTH)
    ) pattern_generator_inst (

        .march_step(march_step),
        .operation_index(operation_index),

        .mem_read(mem_read),
        .mem_write(mem_write),

        .write_data(write_data),
        .expected_data(expected_data)

    );

    //--------------------------------------------------------
    // 4. FAULT INJECTION
    //--------------------------------------------------------

    fault_injection #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) fault_injection_inst (

        .clk(clk),
        .rst(rst),

        .mem_read(mem_read),
        .mem_write(mem_write),

        .addr(addr),

        .normal_read_data(normal_read_data),
        .write_data(write_data),

        .victim_data(victim_data),

        .fault_enable(fault_enable),
        .fault_type(fault_type),

        .fault_address(fault_address),
        .aggressor_address(aggressor_address),

        .stuck_at_value(stuck_at_value),

        .faulty_read_data(faulty_read_data),
        .faulty_write_data(faulty_write_data),

        .fault_write_en(fault_write_en),
        .fault_write_addr(fault_write_addr),
        .fault_write_data(fault_write_data)

    );

    //--------------------------------------------------------
    // 5. SRAM
    //--------------------------------------------------------

    sram_model #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) sram_model_inst (

        .clk(clk),

        .write_en(mem_write),
        .write_addr(addr),
        .write_data(faulty_write_data),

        .read_addr(addr),
        .read_data(normal_read_data),

        .fault_write_en(fault_write_en),
        .fault_write_addr(fault_write_addr),
        .fault_write_data(fault_write_data),

        .victim_read_addr(fault_address),
        .victim_read_data(victim_data)

    );

    //--------------------------------------------------------
    // 6. DATA COMPARATOR
    //--------------------------------------------------------

    data_comparator #(
        .DATA_WIDTH(DATA_WIDTH)
    ) data_comparator_inst (

        .sram_data(faulty_read_data),
        .expected_data(expected_data),

        .compare_enable(mem_read),

        .compare_error(mismatch)

    );

    //--------------------------------------------------------
    // 7. STATUS MONITOR
    //--------------------------------------------------------

    status_monitor status_monitor_inst (

        .clk(clk),
        .rst(rst),

        .start(start),
        .mismatch(mismatch),
        .done(done),

        .fault_detected(fault_detected)

    );

    //--------------------------------------------------------
    // Current address output
    //--------------------------------------------------------

    assign current_address = addr;

    //--------------------------------------------------------
    // Final PASS / FAIL
    //--------------------------------------------------------

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            pass <= 1'b0;
            fail <= 1'b0;

        end

        else begin

            if (start) begin

                pass <= 1'b0;
                fail <= 1'b0;

            end

            if (done) begin

                if (fault_detected) begin

                    pass <= 1'b0;
                    fail <= 1'b1;

                end

                else begin

                    pass <= 1'b1;
                    fail <= 1'b0;

                end

            end

        end

    end

endmodule
