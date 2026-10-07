`timescale 1ns/1ps

module tb_data_comparator;

    localparam DATA_WIDTH = 32;

    logic [DATA_WIDTH-1:0] sram_data;
    logic [DATA_WIDTH-1:0] expected_data;
    logic compare_enable;

    logic compare_error;

    data_comparator #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .sram_data    (sram_data),
        .expected_data(expected_data),
        .compare_enable(compare_enable),
        .compare_error(compare_error)
    );

    initial begin

        $display("========================================");
        $display("   DATA COMPARATOR TEST");
        $display("========================================");

        // -------------------------------------
        // TEST 1: Matching data
        // -------------------------------------
        sram_data = 32'hAAAAAAAA;
        expected_data = 32'hAAAAAAAA;
        compare_enable = 1'b1;

        #1;

        if (compare_error !== 1'b0)
            $error("Comparator incorrectly detected an error");

        $display("TEST 1 PASSED: Matching data");

        // -------------------------------------
        // TEST 2: Mismatching data
        // -------------------------------------
        sram_data = 32'hAAAAAAAA;
        expected_data = 32'h55555555;
        compare_enable = 1'b1;

        #1;

        if (compare_error !== 1'b1)
            $error("Comparator failed to detect mismatch");

        $display("TEST 2 PASSED: Mismatch detected");

        // -------------------------------------
        // TEST 3: Compare disabled
        // -------------------------------------
        sram_data = 32'h00000000;
        expected_data = 32'hFFFFFFFF;
        compare_enable = 1'b0;

        #1;

        if (compare_error !== 1'b0)
            $error("Comparator should be disabled");

        $display("TEST 3 PASSED: Compare disabled");

        // -------------------------------------
        // TEST 4: All zeros match
        // -------------------------------------
        sram_data = 32'h00000000;
        expected_data = 32'h00000000;
        compare_enable = 1'b1;

        #1;

        if (compare_error !== 1'b0)
            $error("Zero comparison failed");

        $display("TEST 4 PASSED");

        // -------------------------------------
        // TEST 5: All ones mismatch
        // -------------------------------------
        sram_data = 32'hFFFFFFFF;
        expected_data = 32'h00000000;
        compare_enable = 1'b1;

        #1;

        if (compare_error !== 1'b1)
            $error("All-ones mismatch not detected");

        $display("TEST 5 PASSED");

        $display("----------------------------------------");
        $display("DATA COMPARATOR TEST PASSED");
        $display("----------------------------------------");

        #10;
        $finish;
    end

endmodule