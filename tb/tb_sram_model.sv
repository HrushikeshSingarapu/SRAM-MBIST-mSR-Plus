`timescale 1ns/1ps

//============================================================
// SRAM model test: write/read, un-initialised cells are X,
// asynchronous read (old value during a same-cycle write),
// write enable, and the verification-only fault-write,
// victim-read and aggressor-read ports.
//============================================================

module tb_sram_model;
    localparam int ADDR_WIDTH = 4;
    localparam int DATA_WIDTH = 32;

    logic clk;
    logic write_en;
    logic [ADDR_WIDTH-1:0] write_addr;
    logic [DATA_WIDTH-1:0] write_data;
    logic [ADDR_WIDTH-1:0] read_addr;
    logic [DATA_WIDTH-1:0] read_data;
    logic fault_write_en;
    logic [ADDR_WIDTH-1:0] fault_write_addr;
    logic [DATA_WIDTH-1:0] fault_write_data;
    logic [ADDR_WIDTH-1:0] victim_read_addr;
    logic [DATA_WIDTH-1:0] victim_read_data;
    logic [ADDR_WIDTH-1:0] aggr_read_addr;
    logic [DATA_WIDTH-1:0] aggr_read_data;

    sram_model #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .write_en(write_en), .write_addr(write_addr), .write_data(write_data),
        .read_addr(read_addr), .read_data(read_data),
        .fault_write_en(fault_write_en), .fault_write_addr(fault_write_addr),
        .fault_write_data(fault_write_data), .victim_read_addr(victim_read_addr),
        .victim_read_data(victim_read_data),
        .aggr_read_addr(aggr_read_addr), .aggr_read_data(aggr_read_data)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    int errors = 0;

    task automatic expect32(input string name, input logic [DATA_WIDTH-1:0] got,
                            input logic [DATA_WIDTH-1:0] exp);
        begin
            if (got !== exp) begin
                $display("ERROR: %s : got %h expected %h", name, got, exp);
                errors++;
            end
        end
    endtask

    task automatic normal_write(input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] d);
        begin
            @(negedge clk); write_addr = a; write_data = d; write_en = 1;
            @(posedge clk); #1; write_en = 0;
        end
    endtask

    initial begin
        write_en = 0; write_addr = 0; write_data = 0; read_addr = 0;
        fault_write_en = 0; fault_write_addr = 0; fault_write_data = 0;
        victim_read_addr = 0; aggr_read_addr = 0;

        // un-written cell is unknown (the algorithm must initialise it)
        read_addr = 4'h3; #1;
        if (^read_data !== 1'bx) begin
            $display("ERROR: un-initialised cell is not X (%h)", read_data); errors++;
        end

        normal_write(4'h0, 32'hAAAAAAAA);
        read_addr = 4'h0; #1; expect32("readback addr 0", read_data, 32'hAAAAAAAA);

        normal_write(4'h5, 32'h12345678);
        read_addr = 4'h5; #1; expect32("readback addr 5", read_data, 32'h12345678);
        read_addr = 4'h0; #1; expect32("addr 0 unchanged", read_data, 32'hAAAAAAAA);

        // write_en = 0 must not write
        @(negedge clk); write_addr = 4'h5; write_data = 32'hDEADBEEF; write_en = 0;
        @(posedge clk); #1;
        read_addr = 4'h5; #1; expect32("no write when write_en=0", read_data, 32'h12345678);

        // asynchronous read: old value visible until the clock edge
        @(negedge clk); write_addr = 4'h5; write_data = 32'h0F0F0F0F; write_en = 1; read_addr = 4'h5;
        #1; expect32("read-during-write returns old data", read_data, 32'h12345678);
        @(posedge clk); #1; write_en = 0;
        expect32("new data after clock edge", read_data, 32'h0F0F0F0F);

        // independent fault-write path
        @(negedge clk);
        fault_write_addr = 4'h0; fault_write_data = 32'h55555555; fault_write_en = 1;
        @(posedge clk); #1; fault_write_en = 0;
        read_addr = 4'h0; #1; expect32("fault write", read_data, 32'h55555555);

        // fault write overrides a normal write to the same address
        @(negedge clk);
        write_addr = 4'h9; write_data = 32'h11111111; write_en = 1;
        fault_write_addr = 4'h9; fault_write_data = 32'h22222222; fault_write_en = 1;
        @(posedge clk); #1; write_en = 0; fault_write_en = 0;
        read_addr = 4'h9; #1; expect32("fault write wins on same address", read_data, 32'h22222222);

        // verification read ports
        victim_read_addr = 4'h5; aggr_read_addr = 4'h0; #1;
        expect32("victim read", victim_read_data, 32'h0F0F0F0F);
        expect32("aggressor read", aggr_read_data, 32'h55555555);

        $display("----------------------------------------");
        if (errors == 0) $display("SRAM MODEL TEST PASSED");
        else             $display("SRAM MODEL TEST FAILED: %0d errors", errors);
        $display("----------------------------------------");
        if (errors != 0) $fatal(1, "sram model errors");
        $finish;
    end
endmodule
