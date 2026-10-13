`timescale 1ns/1ps

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

    sram_model #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .write_en(write_en), .write_addr(write_addr), .write_data(write_data),
        .read_addr(read_addr), .read_data(read_data),
        .fault_write_en(fault_write_en), .fault_write_addr(fault_write_addr),
        .fault_write_data(fault_write_data), .victim_read_addr(victim_read_addr),
        .victim_read_data(victim_read_data)
    );

    always #5 clk = ~clk;

    task automatic normal_write(input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] d);
        begin
            @(negedge clk); write_addr=a; write_data=d; write_en=1;
            @(posedge clk); #1; write_en=0;
        end
    endtask

    initial begin
        clk=0; write_en=0; write_addr=0; write_data=0; read_addr=0;
        fault_write_en=0; fault_write_addr=0; fault_write_data=0; victim_read_addr=0;

        normal_write(4'h0, 32'hAAAAAAAA);
        read_addr=4'h0; #1;
        if (read_data !== 32'hAAAAAAAA) $fatal(1, "Readback address 0 failed");

        normal_write(4'h5, 32'h12345678);
        read_addr=4'h5; #1;
        if (read_data !== 32'h12345678) $fatal(1, "Readback address 5 failed");

        // Independent fault-induced write path.
        @(negedge clk);
        fault_write_addr=4'h0; fault_write_data=32'h55555555; fault_write_en=1;
        @(posedge clk); #1; fault_write_en=0;
        read_addr=4'h0; #1;
        if (read_data !== 32'h55555555) $fatal(1, "Fault write path failed");

        victim_read_addr=4'h5; #1;
        if (victim_read_data !== 32'h12345678) $fatal(1, "Victim read failed");

        $display("----------------------------------------");
        $display("SRAM MODEL TEST PASSED");
        $display("----------------------------------------");
        $finish;
    end
endmodule
