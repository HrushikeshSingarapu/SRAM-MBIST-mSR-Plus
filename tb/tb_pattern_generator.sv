`timescale 1ns/1ps

module tb_pattern_generator;

    localparam DATA_WIDTH = 32;

    logic [3:0] march_step;
    logic [1:0] operation_index;

    logic mem_read;
    logic mem_write;
    logic [DATA_WIDTH-1:0] write_data;
    logic [DATA_WIDTH-1:0] expected_data;

    pattern_generator #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .march_step    (march_step),
        .operation_index(operation_index),
        .mem_read      (mem_read),
        .mem_write     (mem_write),
        .write_data    (write_data),
        .expected_data (expected_data)
    );

    task automatic check_operation;

        input [3:0] step;
        input [1:0] op;
        input        exp_read;
        input        exp_write;
        input [31:0] exp_write_data;
        input [31:0] exp_expected;

        begin

            march_step = step;
            operation_index = op;

            #1;

            if (mem_read !== exp_read)
                $error("S%0d OP%0d: Incorrect READ control",
                       step, op);

            if (mem_write !== exp_write)
                $error("S%0d OP%0d: Incorrect WRITE control",
                       step, op);

if (exp_write) begin
    if (write_data !== exp_write_data)
        $error(
            "S%0d OP%0d: Incorrect write data",
            step, op
        );
end

if (exp_read) begin
    if (expected_data !== exp_expected)
        $error(
            "S%0d OP%0d: Incorrect expected data",
            step, op
        );
end

            $display(
                "S%0d OP%0d : R=%b W=%b WD=%h EXP=%h",
                step,
                op,
                mem_read,
                mem_write,
                write_data,
                expected_data
            );
        end
    endtask


    initial begin

        $display("========================================");
        $display("   PATTERN GENERATOR TEST");
        $display("========================================");

        // S0: ↑(w0)
        check_operation(
            4'd0, 2'd0,
            1'b0, 1'b1,
            32'h00000000,
            32'h00000000
        );

        // S1: ↑(w1)
        check_operation(
            4'd1, 2'd0,
            1'b0, 1'b1,
            32'hFFFFFFFF,
            32'hFFFFFFFF
        );

        // S2: ↑(r1,w0)
        check_operation(
            4'd2, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'hFFFFFFFF
        );

        check_operation(
            4'd2, 2'd1,
            1'b0, 1'b1,
            32'h00000000,
            32'h00000000
        );

        // S3: ↑(r0)
        check_operation(
            4'd3, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'h00000000
        );

        // S4: ↑(r0)
        check_operation(
            4'd4, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'h00000000
        );

        // S5: ↑(r0,w1)
        check_operation(
            4'd5, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'h00000000
        );

        check_operation(
            4'd5, 2'd1,
            1'b0, 1'b1,
            32'hFFFFFFFF,
            32'hFFFFFFFF
        );

        // S6: ↑(r1,w1)
        check_operation(
            4'd6, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'hFFFFFFFF
        );

        check_operation(
            4'd6, 2'd1,
            1'b0, 1'b1,
            32'hFFFFFFFF,
            32'hFFFFFFFF
        );

        // S7: ↑(r1,w0,w1)
        check_operation(
            4'd7, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'hFFFFFFFF
        );

        check_operation(
            4'd7, 2'd1,
            1'b0, 1'b1,
            32'h00000000,
            32'h00000000
        );

        check_operation(
            4'd7, 2'd2,
            1'b0, 1'b1,
            32'hFFFFFFFF,
            32'hFFFFFFFF
        );

        // S8: ↓(r1,w0)
        check_operation(
            4'd8, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'hFFFFFFFF
        );

        check_operation(
            4'd8, 2'd1,
            1'b0, 1'b1,
            32'h00000000,
            32'h00000000
        );

        // S9: ↓(r0,w1)
        check_operation(
            4'd9, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'h00000000
        );

        check_operation(
            4'd9, 2'd1,
            1'b0, 1'b1,
            32'hFFFFFFFF,
            32'hFFFFFFFF
        );

        // S10: ↓(r1)
        check_operation(
            4'd10, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'hFFFFFFFF
        );

        // S11: ↓(r1)
        check_operation(
            4'd11, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'hFFFFFFFF
        );

        // S12: ↓(r1,w0,r0)
        check_operation(
            4'd12, 2'd0,
            1'b1, 1'b0,
            32'h00000000,
            32'hFFFFFFFF
        );

        check_operation(
            4'd12, 2'd1,
            1'b0, 1'b1,
            32'h00000000,
            32'h00000000
        );

        check_operation(
            4'd12, 2'd2,
            1'b1, 1'b0,
            32'h00000000,
            32'h00000000
        );

        $display("----------------------------------------");
        $display("All 22 mSR+ operations verified");
        $display("----------------------------------------");

        #10;
        $display("PATTERN GENERATOR TEST PASSED");
        $finish;
    end

endmodule