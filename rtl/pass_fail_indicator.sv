module pass_fail_indicator (
    input  logic clk,
    input  logic reset,

    input  logic test_complete,
    input  logic test_error,

    output logic pass_led,
    output logic fail_led,
    output logic test_done
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pass_led <= 1'b0;
            fail_led <= 1'b0;
            test_done <= 1'b0;
        end
        else begin

            // Default: no final result until test completes
            if (test_complete) begin

                test_done <= 1'b1;

                if (test_error) begin
                    fail_led <= 1'b1;
                    pass_led <= 1'b0;
                end
                else begin
                    pass_led <= 1'b1;
                    fail_led <= 1'b0;
                end

            end
        end
    end

endmodule