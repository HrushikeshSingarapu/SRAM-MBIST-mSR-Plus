`timescale 1ns/1ps

module sram_model_tb;

    // ------------------------------------------------
    // Parameters
    // ------------------------------------------------
    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 8;

    localparam DEPTH = (1 << ADDR_WIDTH);

    // ------------------------------------------------
    // Testbench signals
    // ------------------------------------------------
    logic clk;
    logic rst;

    logic mem_read;
    logic mem_write;

    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] write_data;

    logic [DATA_WIDTH-1:0] read_data;


    // ------------------------------------------------
    // DUT
    // ------------------------------------------------
    sram_model #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk        (clk),
        .rst        (rst),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .addr       (addr),
        .write_data (write_data),
        .read_data  (read_data)
    );


    // ------------------------------------------------
    // Clock
    // 100 MHz
    // ------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // ------------------------------------------------
    // Test sequence
    // ------------------------------------------------
    initial begin

        // Initial values
        rst        = 1'b1;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        addr       = '0;
        write_data = '0;


        // =================================================
        // TEST 1: RESET
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 1: RESET");
        $display("========================================");

        #20;

        rst = 1'b0;

        $display("PASS: Reset applied and released");


        // =================================================
        // TEST 2: WRITE DATA
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 2: WRITE DATA");
        $display("========================================");

        addr       = 4'd0;
        write_data = 8'hAA;
        mem_write  = 1'b1;

        @(posedge clk);
        #1;

        mem_write = 1'b0;

        $display("Address = %0d, Data written = %h",
                 addr, write_data);


        // =================================================
        // TEST 3: READ DATA
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 3: READ DATA");
        $display("========================================");

        addr     = 4'd0;
        mem_read = 1'b1;

        #2;

        $display("Address = %0d, Expected = %h, Read = %h",
                 addr, 8'hAA, read_data);

        if (read_data !== 8'hAA)
            $fatal(1, "TEST 3 FAILED: Read data mismatch");
        else
            $display("PASS: Read data matches written data");

        mem_read = 1'b0;


        // =================================================
        // TEST 4: WRITE MULTIPLE ADDRESSES
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 4: WRITE MULTIPLE ADDRESSES");
        $display("========================================");

        for (int i = 0; i < DEPTH; i++) begin

            addr       = i;
            write_data = i + 8'h10;
            mem_write  = 1'b1;

            @(posedge clk);
            #1;

            mem_write = 1'b0;

            $display("Address = %0d, Data written = %h",
                     addr, write_data);

        end

        $display("PASS: All memory addresses written");


        // =================================================
        // TEST 5: READ MULTIPLE ADDRESSES
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 5: READ MULTIPLE ADDRESSES");
        $display("========================================");

        for (int i = 0; i < DEPTH; i++) begin

            addr     = i;
            mem_read = 1'b1;

            #2;

            $display("Address = %0d, Expected = %h, Read = %h",
                     addr,
                     i + 8'h10,
                     read_data);

            if (read_data !== (i + 8'h10))
                $fatal(1,
                       "TEST 5 FAILED: Read mismatch at address %0d",
                       i);

        end

        $display("PASS: All memory addresses read correctly");

        mem_read = 1'b0;


        // =================================================
        // TEST 6: OVERWRITE EXISTING LOCATION
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 6: OVERWRITE DATA");
        $display("========================================");

        addr       = 4'd5;
        write_data = 8'h55;
        mem_write  = 1'b1;

        @(posedge clk);
        #1;

        mem_write = 1'b0;

        addr     = 4'd5;
        mem_read = 1'b1;

        #2;

        $display("Address = %0d, Expected = 55, Read = %h",
                 addr, read_data);

        if (read_data !== 8'h55)
            $fatal(1, "TEST 6 FAILED: Memory overwrite failed");
        else
            $display("PASS: Memory overwrite successful");

        mem_read = 1'b0;


        // =================================================
        // TEST 7: READ DISABLED
        // =================================================

        $display("");
        $display("========================================");
        $display("TEST 7: READ DISABLED");
        $display("========================================");

        addr     = 4'd5;
        mem_read = 1'b0;

        #2;

        $display("Read enable = %b, Read data = %h",
                 mem_read, read_data);

        if (read_data !== 8'h00)
            $fatal(1, "TEST 7 FAILED: Read output is not zero");
        else
            $display("PASS: Read output disabled correctly");


        // =================================================
        // FINISH
        // =================================================

        $display("");
        $display("========================================");
        $display("ALL SRAM TESTS PASSED");
        $display("========================================");

        #20;

        $finish;

    end

endmodule
