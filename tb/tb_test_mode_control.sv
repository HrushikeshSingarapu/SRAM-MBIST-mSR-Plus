`timescale 1ns/1ps

module tb_test_mode_control;

    logic clk;
    logic reset;
    logic test_mode;

    logic bist_mem_read;
    logic bist_mem_write;

    logic sram_mode;
    logic addr_en;
    logic mem_read;
    logic mem_write;

    test_mode_control dut (
        .clk(clk),
        .reset(reset),
        .test_mode(test_mode),
        .bist_mem_read(bist_mem_read),
        .bist_mem_write(bist_mem_write),
        .sram_mode(sram_mode),
        .addr_en(addr_en),
        .mem_read(mem_read),
        .mem_write(mem_write)
    );

    always #5 clk = ~clk;

task check_outputs(
    input logic exp_sram_mode,
    input logic exp_addr_en,
    input logic exp_read,
    input logic exp_write
);
    begin
        if (sram_mode !== exp_sram_mode ||
            addr_en   !== exp_addr_en   ||
            mem_read  !== exp_read      ||
            mem_write !== exp_write) begin

            $display("ERROR: mode=%b read=%b write=%b | Got: mode=%b addr_en=%b read=%b write=%b",
                     test_mode, bist_mem_read, bist_mem_write,
                     sram_mode, addr_en, mem_read, mem_write);

            $fatal;
        end
    end
endtask

    initial begin
        clk = 0;
        reset = 1;
        test_mode = 0;
        bist_mem_read = 0;
        bist_mem_write = 0;

        #12;
        reset = 0;

        // TEST 1: Normal mode
        @(negedge clk);
        test_mode = 0;
        bist_mem_read = 0;
        bist_mem_write = 0;

        @(posedge clk);
        #1;
        check_outputs(0, 0, 0, 0);
        $display("TEST 1 PASSED: Normal mode");

        // TEST 2: Test mode - write
        @(negedge clk);
        test_mode = 1;
        bist_mem_read = 0;
        bist_mem_write = 1;

        @(posedge clk);
        #1;
        check_outputs(1, 1, 0, 1);
        $display("TEST 2 PASSED: Test mode write");

        // TEST 3: Test mode - read
        @(negedge clk);
        bist_mem_read = 1;
        bist_mem_write = 0;

        @(posedge clk);
        #1;
        check_outputs(1, 1, 1, 0);
        $display("TEST 3 PASSED: Test mode read");

        // TEST 4: Test mode - both disabled
        @(negedge clk);
        bist_mem_read = 0;
        bist_mem_write = 0;

        @(posedge clk);
        #1;
        check_outputs(1, 1, 0, 0);
        $display("TEST 4 PASSED: Test mode idle");

        // TEST 5: Return to normal mode
        @(negedge clk);
        test_mode = 0;
        bist_mem_read = 1;
        bist_mem_write = 1;

        @(posedge clk);
        #1;
        check_outputs(0, 0, 0, 0);
        $display("TEST 5 PASSED: Normal mode overrides BIST controls");

        $display("----------------------------------------");
        $display("TEST MODE CONTROL TEST PASSED");
        $display("----------------------------------------");

        $finish;
    end

endmodule