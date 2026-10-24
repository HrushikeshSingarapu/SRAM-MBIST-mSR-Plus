//============================================================
// Data Comparator
//
// Paper block:
//     Data_Comparator / data_comp
//
// Compares actual SRAM read data against the expected
// March-pattern data.
//
// compare_error is asserted only while compare_enable is
// high (a valid read operation).
//
// Unknown (X/Z) read data is treated as a MISMATCH in
// simulation, so an uninitialised or undriven cell can never
// be mistaken for a successful comparison. (The X check sits
// inside synthesis translate_off/on, because X does not exist
// in hardware; the synthesised logic is the plain != compare.)
//============================================================

module data_comparator #(
    parameter int DATA_WIDTH = 32
)(
    input logic [DATA_WIDTH-1:0] sram_data,
    input logic [DATA_WIDTH-1:0] expected_data,

    input logic                  compare_enable,

    output logic                 compare_error
);

    always_comb begin

        if (compare_enable)
            compare_error = (sram_data != expected_data);

        else
            compare_error = 1'b0;

        // synthesis translate_off
        if (compare_enable && ((^sram_data) === 1'bx))
            compare_error = 1'b1;
        // synthesis translate_on

    end

endmodule
