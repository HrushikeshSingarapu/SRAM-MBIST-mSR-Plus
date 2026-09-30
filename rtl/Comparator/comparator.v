module comparator #(
    parameter DATA_WIDTH = 8
)(
    input  wire [DATA_WIDTH-1:0] expected_data,
    input  wire [DATA_WIDTH-1:0] actual_data,
    input  wire                  compare_en,
    output wire                  mismatch
);
    assign mismatch = compare_en &&
                      (expected_data != actual_data);
endmodule
