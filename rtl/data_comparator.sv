//============================================================
// Data Comparator
//
// Paper block:
//     Data_Comparator / data_comp
//
// Compares actual SRAM read data against the expected
// March-pattern data.
//
// SRAM data width shown in Fig. 3:
//     32 bits
//============================================================

module data_comparator #(
    parameter int DATA_WIDTH = 32
)(
    input logic [DATA_WIDTH-1:0] sram_data,
    input logic [DATA_WIDTH-1:0] expected_data,

    input logic                  compare_enable,

    output logic                 compare_error
);

    //--------------------------------------------------------
    // Data comparison
    //--------------------------------------------------------

    always_comb begin

        if (compare_enable)
            compare_error = (sram_data != expected_data);

        else
            compare_error = 1'b0;

    end

endmodule