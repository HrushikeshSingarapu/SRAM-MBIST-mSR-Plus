`timescale 1ns/1ps

module tb_comparator;

    parameter DATA_WIDTH = 8;

    reg [DATA_WIDTH-1:0] expected_data;
    reg [DATA_WIDTH-1:0] actual_data;
    reg compare_en;

    wire mismatch;

    comparator #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .expected_data(expected_data),
        .actual_data(actual_data),
        .compare_en(compare_en),
        .mismatch(mismatch)
    );

    initial begin
        $monitor("Time=%0t | Expected=%h | Actual=%h | Enable=%b | Mismatch=%b",
                 $time, expected_data, actual_data, compare_en, mismatch);

        // Test 1: Matching data
        expected_data = 8'hA5;
        actual_data   = 8'hA5;
        compare_en    = 1;
        #10;
        if (mismatch !== 0)
            $fatal(1, "TEST 1 FAILED: Matching data");
        else
            $display("TEST 1 PASSED: Matching data");

        // Test 2: Mismatching data
        expected_data = 8'hA5;
        actual_data   = 8'h5A;
        compare_en    = 1;
        #10;
        if (mismatch !== 1)
            $fatal(1, "TEST 2 FAILED: Mismatch detection");
        else
            $display("TEST 2 PASSED: Mismatch detected");

        // Test 3: Comparator disabled
        expected_data = 8'hAA;
        actual_data   = 8'h55;
        compare_en    = 0;
        #10;
        if (mismatch !== 0)
            $fatal(1, "TEST 3 FAILED: Comparator disabled");
        else
            $display("TEST 3 PASSED: Comparator disabled");

        // Test 4: Matching data with comparator disabled
        expected_data = 8'h3C;
        actual_data   = 8'h3C;
        compare_en    = 0;
        #10;
        if (mismatch !== 0)
            $fatal(1, "TEST 4 FAILED: Matching data with comparator disabled");
        else
            $display("TEST 4 PASSED: Matching data with comparator disabled");

        $display("Comparator testing completed");
        $finish;
    end

endmodule
