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
        .clk       (clk),
        .rst       (rst),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .addr      (addr),
        .write_data(write_data),
        .read_data (read_data)
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
    // Test
    // ------------------------------------------------
    initial begin

        // Initial values
        rst        = 1'b1;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        addr       = '0;
        write_data = '0;

        // ------------------------------------------------
        // TEST 1: RESET
        // ------------------------------------------------
        $display("");
        $display("========================================");
        $display("TEST 1: RESET");
        $display("========================================");

        #20;

        rst = 1'b0;

        $display("PASS: Reset completed");


        // ------------------------------------------------
        // TEST 2: WRITE DATA
        // ------------------------------------------------
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


        // ------------------------------------------------
        // TEST 3: READ DATA
        // ------------------------------------------------
        $display("");
        $display("========================================");
        $display("TEST 3: READ DATA");
        $display("========================================");

        addr      = 4'd0;
        mem_read  = 1'b1;

        #2;

        $display("Address = %0d, Read data = %h",
                 addr, read_data);

        if (read_data == 8'hAA)
            $display("PASS: Read data matches written data");
        else
            $display("FAIL: Read data does not match");

        mem_read = 1'b0;


        // ------------------------------------------------
        // TEST 4: WRITE MULTIPLE ADDRESSES
        // ------------------------------------------------
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

            $display("Address = %0d, Data = %h",
                     addr, write_data);
        end

        $display("PASS: Multiple address writes completed");


        // ------------------------------------------------
        // TEST 5: READ MULTIPLE ADDRESSES
        // ------------------------------------------------
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

            if (read_data == (i + 8'h10))
                $display("PASS");
            else
                $display("FAIL");

        end

        mem_read = 1'b0;


        // ------------------------------------------------
        // TEST 6: OVERWRITE EXISTING LOCATION
        // ------------------------------------------------
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

        $display("Address = %0d, New data = %h",
                 addr, read_data);

        if (read_data == 8'h55)
            $display("PASS: Memory overwrite successful");
        else
            $display("FAIL: Memory overwrite failed");

        mem_read = 1'b0;


        // ------------------------------------------------
        // TEST 7: READ DISABLED
        // ------------------------------------------------
        $display("");
        $display("========================================");
        $display("TEST 7: READ DISABLED");
        $display("========================================");

        addr     = 4'd5;
        mem_read = 1'b0;

        #2;

        $display("Read enable = %b, Read data = %h",
                 mem_read, read_data);

        if (read_data == 8'h00)
            $display("PASS: Read output disabled correctly");
        else
            $display("FAIL: Read output not zero");

        
        // ------------------------------------------------
        // FINISH
        // ------------------------------------------------
        $display("");
        $display("========================================");
        $display("ALL SRAM TESTS COMPLETED");
        $display("========================================");

        #20;

        $finish;

    end

endmodule