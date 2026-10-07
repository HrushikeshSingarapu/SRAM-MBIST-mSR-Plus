`timescale 1ns/1ps

module tb_sram_model;

    localparam ADDR_WIDTH = 8;
    localparam DATA_WIDTH = 32;

    logic clk;
    logic reset;

    logic mem_read;
    logic mem_write;

    logic [ADDR_WIDTH-1:0] sram_addr;
    logic [DATA_WIDTH-1:0] sram_write_data;
    logic [DATA_WIDTH-1:0] sram_read_data;


    //============================================================
    // DUT
    //============================================================

    sram_model #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk             (clk),
        .reset           (reset),
        .mem_read        (mem_read),
        .mem_write       (mem_write),
        .sram_addr       (sram_addr),
        .sram_write_data (sram_write_data),
        .sram_read_data  (sram_read_data)
    );


    //============================================================
    // Clock Generation
    // 10 ns period
    //============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    //============================================================
    // SRAM Test
    //============================================================

    initial begin

        // -------------------------------------------------------
        // Initial values
        // -------------------------------------------------------

        reset          = 1'b1;
        mem_read       = 1'b0;
        mem_write      = 1'b0;
        sram_addr      = 8'h00;
        sram_write_data = 32'h00000000;


        // -------------------------------------------------------
        // Reset
        // -------------------------------------------------------

        #10;

        reset = 1'b0;


        $display("========================================");
        $display("          SRAM MODEL TEST");
        $display("========================================");


        //========================================================
        // TEST 1: Write address 0
        //========================================================

        @(negedge clk);

        sram_addr       = 8'h00;
        sram_write_data = 32'hAAAAAAAA;
        mem_write       = 1'b1;

        // Write captured at rising edge
        @(posedge clk);

        #1;

        mem_write = 1'b0;

        $display("TEST 1: Address 0 written with AAAAAAAA");


        //========================================================
        // TEST 2: Read address 0
        //========================================================

        sram_addr = 8'h00;
        mem_read  = 1'b1;

        #1;

        if (sram_read_data !== 32'hAAAAAAAA) begin

            $error(
                "SRAM read failed at address 0. Got %h",
                sram_read_data
            );

            $fatal(1, "TEST 2 FAILED");

        end

        else begin

            $display("TEST 2 PASSED: Read address 0");

        end


        //========================================================
        // TEST 3: Write address 55
        //========================================================

        mem_read = 1'b0;

        @(negedge clk);

        sram_addr       = 8'h55;
        sram_write_data = 32'h12345678;
        mem_write       = 1'b1;

        // Write captured at rising edge
        @(posedge clk);

        #1;

        mem_write = 1'b0;

        $display("TEST 3: Address 55 written with 12345678");


        //========================================================
        // TEST 4: Read address 55
        //========================================================

        sram_addr = 8'h55;
        mem_read  = 1'b1;

        #1;

        if (sram_read_data !== 32'h12345678) begin

            $error(
                "SRAM read failed at address 55. Got %h",
                sram_read_data
            );

            $fatal(1, "TEST 4 FAILED");

        end

        else begin

            $display("TEST 4 PASSED: Read address 55");

        end


        //========================================================
        // TEST 5: Check address 0 retained its data
        //========================================================

        sram_addr = 8'h00;

        #1;

        if (sram_read_data !== 32'hAAAAAAAA) begin

            $error(
                "Data at address 0 was corrupted. Got %h",
                sram_read_data
            );

            $fatal(1, "TEST 5 FAILED");

        end

        else begin

            $display("TEST 5 PASSED: Address 0 retained data");

        end


        //========================================================
        // TEST 6: Overwrite address 0
        //========================================================

        mem_read = 1'b0;

        @(negedge clk);

        sram_addr       = 8'h00;
        sram_write_data = 32'hFFFFFFFF;
        mem_write       = 1'b1;

        // Write captured at rising edge
        @(posedge clk);

        #1;

        mem_write = 1'b0;


        // Read overwritten data
        sram_addr = 8'h00;
        mem_read  = 1'b1;

        #1;

        if (sram_read_data !== 32'hFFFFFFFF) begin

            $error(
                "SRAM overwrite failed. Got %h",
                sram_read_data
            );

            $fatal(1, "TEST 6 FAILED");

        end

        else begin

            $display("TEST 6 PASSED: SRAM overwrite");

        end

//
        //========================================================
        // Final result
        //========================================================

        $display("----------------------------------------");
        $display("      SRAM MODEL TEST PASSED");
        $display("----------------------------------------");

        #10;

        $finish;

    end

endmodule