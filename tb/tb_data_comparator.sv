`timescale 1ns/1ps

//============================================================
// Data comparator test (self-checking, fails the simulation
// on any error). Includes X/Z read data, which must never be
// treated as a successful comparison.
//============================================================

module tb_data_comparator;

    localparam int DATA_WIDTH = 32;

    logic [DATA_WIDTH-1:0] sram_data;
    logic [DATA_WIDTH-1:0] expected_data;
    logic compare_enable;
    logic compare_error;

    data_comparator #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .sram_data(sram_data), .expected_data(expected_data),
        .compare_enable(compare_enable), .compare_error(compare_error)
    );

    int errors = 0;

    task automatic check(input string name, input logic exp);
        begin
            #1;
            if (compare_error !== exp) begin
                $display("ERROR: %s : compare_error=%b expected %b", name, compare_error, exp);
                errors++;
            end
        end
    endtask

    initial begin
        compare_enable = 1;

        sram_data = 32'hAAAAAAAA; expected_data = 32'hAAAAAAAA; check("match AAAA", 1'b0);
        sram_data = 32'hAAAAAAAA; expected_data = 32'h55555555; check("mismatch", 1'b1);
        sram_data = 32'h00000000; expected_data = 32'h00000000; check("all-0 match", 1'b0);
        sram_data = 32'hFFFFFFFF; expected_data = 32'hFFFFFFFF; check("all-1 match", 1'b0);
        sram_data = 32'hFFFFFFFF; expected_data = 32'h00000000; check("all-1 vs all-0", 1'b1);
        sram_data = 32'h00000000; expected_data = 32'hFFFFFFFF; check("all-0 vs all-1", 1'b1);

        // single-bit difference in every position
        for (int b = 0; b < DATA_WIDTH; b++) begin
            sram_data = 32'hFFFFFFFF ^ (32'h1 << b); expected_data = 32'hFFFFFFFF;
            check("single-bit difference", 1'b1);
        end

        // disabled comparator never reports an error
        compare_enable = 0;
        sram_data = 32'h00000000; expected_data = 32'hFFFFFFFF; check("disabled", 1'b0);
        sram_data = 'x;                                          check("disabled, X data", 1'b0);

        // X / Z read data while enabled = mismatch (never a pass)
        compare_enable = 1;
        sram_data = 'x; expected_data = 32'h00000000; check("X data (exp 0)", 1'b1);
        sram_data = 'x; expected_data = 32'hFFFFFFFF; check("X data (exp 1)", 1'b1);
        sram_data = 'z; expected_data = 32'h00000000; check("Z data", 1'b1);
        sram_data = 32'hFFFFFFFE; sram_data[5] = 1'bx; expected_data = 32'hFFFFFFFF;
        check("one X bit", 1'b1);

        $display("----------------------------------------");
        if (errors == 0) $display("DATA COMPARATOR TEST PASSED");
        else             $display("DATA COMPARATOR TEST FAILED: %0d errors", errors);
        $display("----------------------------------------");
        if (errors != 0) $fatal(1, "data comparator errors");
        $finish;
    end

endmodule
