//============================================================
// MBIST TOP
//
// Complete SRAM MBIST integration (March mSR+)
//
// March mSR+  (13 March elements, 22 operations per cell)
// S0  UP   (w0)
// S1  UP   (w1)
// S2  UP   (r1,w0)
// S3  UP   (r0)
// S4  UP   (r0)
// S5  UP   (r0,w1)
// S6  UP   (r1,w1)
// S7  UP   (r1,w0,w1)
// S8  DOWN (r1,w0)
// S9  DOWN (r0,w1)
// S10 DOWN (r1)
// S11 DOWN (r1)
// S12 DOWN (r1,w0,r0)
//
// Interface semantics
//   start  : pulse for >= 1 clock while the BIST is idle. A start
//            while busy is ignored.
//   busy   : high from the cycle after start until just before
//            done rises (continuous - no gap).
//   done   : rises TOGETHER with pass/fail and then stays high
//            until the next start (or reset). When done=1,
//            pass/fail are valid and final.
//   pass   : done && no mismatch was seen during the whole test.
//   fail   : done && at least one mismatch was seen (latched in
//            status_monitor for the whole test).
//   pass and fail are both 0 from start until done.
//
// fault_enable/fault_type/fault_address/aggressor_address/
// stuck_at_value/fault_variant configure the verification-only
// fault injector (see fault_injection.sv). With fault_enable = 0
// the memory is fault-free.
//
// test_mode_control gates the pattern generator's read/write
// strobes with 'busy', so the SRAM is never accessed while the
// BIST is idle or finished. (Without this gate the pattern
// generator decodes march_step 0 as S0 and writes 0 to the SRAM
// whenever the controller is idle.)
//
// pass_fail_indicator and fault_logger are stand-alone IP blocks
// with their own unit tests; they are not instantiated here
// (the top level uses status_monitor + registered pass/fail).
//============================================================

module mbist_top #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst,
    input logic start,

    //--------------------------------------------------------
    // Fault injection configuration (verification only)
    //--------------------------------------------------------

    input logic                  fault_enable,
    input logic [3:0]            fault_type,

    input logic [ADDR_WIDTH-1:0] fault_address,
    input logic [ADDR_WIDTH-1:0] aggressor_address,

    input logic                  stuck_at_value,
    input logic                  fault_variant,

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

    logic ctrl_busy;
    logic ctrl_done;

    // start is accepted only while the BIST is idle. A start pulse
    // during a running test is ignored completely (it must not
    // clear a mismatch that has already been latched).
    logic start_ok;

    logic restart_direction_up;
    logic cell_complete;
    logic step_complete;
    logic address_restart;
    logic last_addr;

    //--------------------------------------------------------
    // Pattern generator / test-mode signals
    //--------------------------------------------------------

    logic pg_read;
    logic pg_write;

    logic mem_read;
    logic mem_write;

    logic sram_mode;
    logic addr_en;

    logic [DATA_WIDTH-1:0] write_data;
    logic [DATA_WIDTH-1:0] expected_data;

    //--------------------------------------------------------
    // SRAM signals
    //--------------------------------------------------------

    logic [DATA_WIDTH-1:0] normal_read_data;
    logic [DATA_WIDTH-1:0] victim_data;
    logic [DATA_WIDTH-1:0] aggressor_data;

    //--------------------------------------------------------
    // Fault injection signals
    //--------------------------------------------------------

    logic [DATA_WIDTH-1:0] faulty_read_data;
    logic [DATA_WIDTH-1:0] faulty_write_data;

    logic                  fault_write_en;
    logic [ADDR_WIDTH-1:0] fault_write_addr;
    logic [DATA_WIDTH-1:0] fault_write_data;

    logic                  fault_activated;

    //--------------------------------------------------------
    // Comparator / status
    //--------------------------------------------------------

    logic mismatch;
    logic fault_detected;

    //--------------------------------------------------------
    // Address
    //--------------------------------------------------------

    logic [ADDR_WIDTH-1:0] addr;

    assign start_ok = start & ~busy;

    //--------------------------------------------------------
    // 1. BIST CONTROLLER
    //--------------------------------------------------------

    bist_controller bist_controller_inst (

        .clk(clk),
        .rst(rst),
        .start(start_ok),

        .last_addr(last_addr),

        .busy(ctrl_busy),
        .done(ctrl_done),

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

        .mem_read(pg_read),
        .mem_write(pg_write),

        .write_data(write_data),
        .expected_data(expected_data)

    );

    //--------------------------------------------------------
    // 4. TEST MODE CONTROL
    //    test_mode = BIST busy: SRAM strobes pass through only
    //    while a March test is actually running.
    //--------------------------------------------------------

    test_mode_control test_mode_control_inst (

        .clk(clk),
        .reset(rst),

        .test_mode(ctrl_busy),

        .bist_mem_read(pg_read),
        .bist_mem_write(pg_write),

        .sram_mode(sram_mode),
        .addr_en(addr_en),
        .mem_read(mem_read),
        .mem_write(mem_write)

    );

    //--------------------------------------------------------
    // 5. FAULT INJECTION
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
        .aggressor_data(aggressor_data),

        .fault_enable(fault_enable),
        .fault_type(fault_type),

        .fault_address(fault_address),
        .aggressor_address(aggressor_address),

        .stuck_at_value(stuck_at_value),
        .fault_variant(fault_variant),

        .faulty_read_data(faulty_read_data),
        .faulty_write_data(faulty_write_data),

        .fault_write_en(fault_write_en),
        .fault_write_addr(fault_write_addr),
        .fault_write_data(fault_write_data),

        .fault_activated(fault_activated)

    );

    //--------------------------------------------------------
    // 6. SRAM
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
        .victim_read_data(victim_data),

        .aggr_read_addr(aggressor_address),
        .aggr_read_data(aggressor_data)

    );

    //--------------------------------------------------------
    // 7. DATA COMPARATOR
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
    // 8. STATUS MONITOR  (latches any mismatch for the whole test)
    //--------------------------------------------------------

    status_monitor status_monitor_inst (

        .clk(clk),
        .rst(rst),

        .start(start_ok),
        .mismatch(mismatch),
        .done(ctrl_done),

        .fault_detected(fault_detected)

    );

    //--------------------------------------------------------
    // Outputs
    //--------------------------------------------------------

    assign current_address = addr;

    // busy covers the controller's DONE cycle too, so there is
    // no cycle where busy=0 and done=0 at the end of a test.
    assign busy = ctrl_busy | ctrl_done;

    //--------------------------------------------------------
    // Final DONE / PASS / FAIL
    //
    // Captured in the controller's DONE cycle (fault_detected
    // already contains the last comparison) and held until the
    // next start or reset. done rises together with pass/fail.
    //--------------------------------------------------------

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            done <= 1'b0;
            pass <= 1'b0;
            fail <= 1'b0;

        end

        else begin

            if (start_ok) begin

                done <= 1'b0;
                pass <= 1'b0;
                fail <= 1'b0;

            end

            if (ctrl_done) begin

                done <= 1'b1;
                pass <= ~fault_detected;
                fail <=  fault_detected;

            end

        end

    end

endmodule
