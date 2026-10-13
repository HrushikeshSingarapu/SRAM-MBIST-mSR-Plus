`timescale 1ns/1ps

//============================================================
// TESTBENCH : FAULT INJECTION
//
// Tests all 11 fault models used in the paper's
// fault-specific evaluation.
//
// 0  SAF
// 1  TF
// 2  CFid
// 3  CFdrd
// 4  CFin
// 5  RDF
// 6  DRDF
// 7  IRF
// 8  CFtr
// 9  CFwd
// 10 WDF
//
// This testbench verifies the behavioral fault-injection
// mechanism. Full detection by the complete mSR+ MBIST
// will be verified later through tb_mbist_top.
//============================================================

module tb_fault_injection;


    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;


    //--------------------------------------------------------
    // Clock and reset
    //--------------------------------------------------------

    logic clk;
    logic rst;


    //--------------------------------------------------------
    // SRAM interface
    //--------------------------------------------------------

    logic mem_read;
    logic mem_write;

    logic [ADDR_WIDTH-1:0] addr;

    logic [DATA_WIDTH-1:0] normal_read_data;
    logic [DATA_WIDTH-1:0] write_data;


    //--------------------------------------------------------
    // Fault controls
    //--------------------------------------------------------

    logic fault_enable;

    logic [3:0] fault_type;

    logic [ADDR_WIDTH-1:0] fault_address;

    logic [ADDR_WIDTH-1:0] aggressor_address;

    logic stuck_at_value;


    //--------------------------------------------------------
    // Fault outputs
    //--------------------------------------------------------

    logic [DATA_WIDTH-1:0] faulty_read_data;

    logic [DATA_WIDTH-1:0] faulty_write_data;


    //--------------------------------------------------------
    // Fault constants
    //--------------------------------------------------------

    localparam logic [3:0] FAULT_SAF   = 4'd0;
    localparam logic [3:0] FAULT_TF    = 4'd1;
    localparam logic [3:0] FAULT_CFID  = 4'd2;
    localparam logic [3:0] FAULT_CFDRD = 4'd3;
    localparam logic [3:0] FAULT_CFIN  = 4'd4;
    localparam logic [3:0] FAULT_RDF   = 4'd5;
    localparam logic [3:0] FAULT_DRDF  = 4'd6;
    localparam logic [3:0] FAULT_IRF   = 4'd7;
    localparam logic [3:0] FAULT_CFTR  = 4'd8;
    localparam logic [3:0] FAULT_CFWD  = 4'd9;
    localparam logic [3:0] FAULT_WDF   = 4'd10;


    //--------------------------------------------------------
    // DUT
    //--------------------------------------------------------

    fault_injection #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (

        .clk                  (clk),
        .rst                  (rst),

        .mem_read             (mem_read),
        .mem_write            (mem_write),

        .addr                 (addr),

        .normal_read_data     (normal_read_data),
        .write_data           (write_data),

        .fault_enable         (fault_enable),
        .fault_type           (fault_type),

        .fault_address        (fault_address),
        .aggressor_address    (aggressor_address),

        .stuck_at_value       (stuck_at_value),

        .faulty_read_data     (faulty_read_data),
        .faulty_write_data    (faulty_write_data)

    );


    //--------------------------------------------------------
    // Clock
    //--------------------------------------------------------

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    //--------------------------------------------------------
    // Helper task
    //--------------------------------------------------------

    task automatic clear_controls;

        begin

            mem_read          = 1'b0;
            mem_write         = 1'b0;

            addr              = 8'h10;

            normal_read_data  = 32'hAAAAAAAA;
            write_data        = 32'hAAAAAAAA;

            fault_enable      = 1'b0;

            fault_type        = FAULT_SAF;

            fault_address     = 8'h10;
            aggressor_address = 8'h11;

            stuck_at_value    = 1'b0;

        end

    endtask


    //--------------------------------------------------------
    // Test
    //--------------------------------------------------------

    initial begin


        //----------------------------------------------------
        // Initial values
        //----------------------------------------------------

        clear_controls();

        rst = 1'b1;

        #20;

        rst = 1'b0;

        #10;


        //----------------------------------------------------
        // TEST 1 : SAF-0
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 1 : SAF-0");
        $display("========================================");

        fault_enable   = 1'b1;
        fault_type     = FAULT_SAF;
        stuck_at_value = 1'b0;

        addr           = 8'h10;
        normal_read_data = 32'hFFFFFFFF;
        mem_read       = 1'b1;

        #10;

        if (faulty_read_data === 32'h00000000)
            $display("SAF-0 PASS");

        else
            $display("SAF-0 FAIL : DATA=%h",
                     faulty_read_data);


        //----------------------------------------------------
        // TEST 2 : SAF-1
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 2 : SAF-1");
        $display("========================================");

        fault_type     = FAULT_SAF;
        stuck_at_value = 1'b1;

        normal_read_data = 32'h00000000;

        #10;

        if (faulty_read_data === 32'hFFFFFFFF)
            $display("SAF-1 PASS");

        else
            $display("SAF-1 FAIL : DATA=%h",
                     faulty_read_data);


        //----------------------------------------------------
        // TEST 3 : TF
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 3 : TF");
        $display("========================================");

        clear_controls();

        fault_enable = 1'b1;
        fault_type   = FAULT_TF;

        fault_address = 8'h10;

        // Establish previous value
        addr       = 8'h10;
        mem_write  = 1'b1;
        write_data = 32'h00000000;

        @(posedge clk);

        mem_write = 1'b0;

        // Attempt transition
        write_data = 32'hFFFFFFFF;

        #10;

        if (faulty_write_data === 32'h00000000)
            $display("TF PASS");

        else
            $display("TF FAIL : WRITE=%h",
                     faulty_write_data);


        //----------------------------------------------------
        // TEST 4 : CFid
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 4 : CFid");
        $display("========================================");

        clear_controls();

        fault_enable = 1'b1;
        fault_type   = FAULT_CFID;

        fault_address     = 8'h10;
        aggressor_address = 8'h11;

        // Access aggressor
        addr      = 8'h11;
        mem_write = 1'b1;

        @(posedge clk);

        mem_write = 1'b0;

        // Read victim
        addr             = 8'h10;
        mem_read         = 1'b1;
        normal_read_data = 32'hAAAAAAAA;

        #10;

        if (faulty_read_data === 32'h55555555)
            $display("CFid PASS");

        else
            $display("CFid FAIL : DATA=%h",
                     faulty_read_data);


        //----------------------------------------------------
        // TEST 5 : CFdrd
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 5 : CFdrd");
        $display("========================================");

        clear_controls();

        fault_enable = 1'b1;
        fault_type   = FAULT_CFDRD;

        fault_address     = 8'h10;
        aggressor_address = 8'h11;

        // Aggressor read
        addr      = 8'h11;
        mem_read  = 1'b1;

        @(posedge clk);

        // Victim read
        addr             = 8'h10;
        normal_read_data = 32'hAAAAAAAA;

        #10;

        if (faulty_read_data === 32'h55555555)
            $display("CFdrd PASS");

        else
            $display("CFdrd FAIL : DATA=%h",
                     faulty_read_data);


        //----------------------------------------------------
        // TEST 6 : CFin
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 6 : CFin");
        $display("========================================");

        clear_controls();

        fault_enable = 1'b1;
        fault_type   = FAULT_CFIN;

        fault_address     = 8'h10;
        aggressor_address = 8'h11;

        addr      = 8'h11;
        mem_write = 1'b1;

        @(posedge clk);

        mem_write = 1'b0;

        addr             = 8'h10;
        mem_read         = 1'b1;
        normal_read_data = 32'hAAAAAAAA;

        #10;

        if (faulty_read_data === 32'h55555555)
            $display("CFin PASS");

        else
            $display("CFin FAIL : DATA=%h",
                     faulty_read_data);


        //----------------------------------------------------
        // TEST 7 : RDF
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 7 : RDF");
        $display("========================================");

        clear_controls();

        fault_enable = 1'b1;
        fault_type   = FAULT_RDF;

        fault_address = 8'h10;

        addr             = 8'h10;
        normal_read_data = 32'hAAAAAAAA;
        mem_read         = 1'b1;

        // First read
        @(posedge clk);

        #1;

        // Second observation after disturbance
        #9;

        if (faulty_read_data === 32'h55555555)
            $display("RDF PASS");

        else
            $display("RDF FAIL : DATA=%h",
                     faulty_read_data);


        //----------------------------------------------------
        // TEST 8 : DRDF
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 8 : DRDF");
        $display("========================================");

        clear_controls();

        fault_enable = 1'b1;
        fault_type   = FAULT_DRDF;

        fault_address = 8'h10;

        addr             = 8'h10;
        normal_read_data = 32'hAAAAAAAA;
        mem_read         = 1'b1;

        // First read
        @(posedge clk);

        // Second read
        @(posedge clk);

        #1;

        if (faulty_read_data === 32'h55555555)
            $display("DRDF PASS");

        else
            $display("DRDF FAIL : DATA=%h",
                     faulty_read_data);


        //----------------------------------------------------
        // TEST 9 : IRF
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 9 : IRF");
        $display("========================================");

        clear_controls();

        fault_enable = 1'b1;
        fault_type   = FAULT_IRF;

        fault_address = 8'h10;

        addr             = 8'h10;
        normal_read_data = 32'hAAAAAAAA;
        mem_read         = 1'b1;

        #10;

        if (faulty_read_data === 32'h55555555)
            $display("IRF PASS");

        else
            $display("IRF FAIL : DATA=%h",
                     faulty_read_data);


        //----------------------------------------------------
        // TEST 10 : CFtr
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 10 : CFtr");
        $display("========================================");

        clear_controls();

        fault_enable = 1'b1;
        fault_type   = FAULT_CFTR;

        fault_address     = 8'h10;
        aggressor_address = 8'h11;

        addr      = 8'h11;
        mem_write = 1'b1;

        @(posedge clk);

        mem_write = 1'b0;

        addr             = 8'h10;
        mem_read         = 1'b1;
        normal_read_data = 32'hAAAAAAAA;

        #10;

        if (faulty_read_data === 32'h55555555)
            $display("CFtr PASS");

        else
            $display("CFtr FAIL : DATA=%h",
                     faulty_read_data);


        //----------------------------------------------------
        // TEST 11 : CFwd
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 11 : CFwd");
        $display("========================================");

        clear_controls();

        fault_enable = 1'b1;
        fault_type   = FAULT_CFWD;

        fault_address     = 8'h10;
        aggressor_address = 8'h11;

        addr      = 8'h11;
        mem_write = 1'b1;

        @(posedge clk);

        mem_write = 1'b0;

        addr             = 8'h10;
        mem_read         = 1'b1;
        normal_read_data = 32'hAAAAAAAA;

        #10;

        if (faulty_read_data === 32'h55555555)
            $display("CFwd PASS");

        else
            $display("CFwd FAIL : DATA=%h",
                     faulty_read_data);


        //----------------------------------------------------
        // TEST 12 : WDF
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("TEST 12 : WDF");
        $display("========================================");

        clear_controls();

        fault_enable = 1'b1;
        fault_type   = FAULT_WDF;

        fault_address = 8'h10;

        // Existing value
        addr       = 8'h10;
        mem_write  = 1'b1;
        write_data = 32'h00000000;

        @(posedge clk);

        mem_write = 1'b0;

        // Attempt new write
        write_data = 32'hFFFFFFFF;

        #10;

        if (faulty_write_data === 32'h00000000)
            $display("WDF PASS");

        else
            $display("WDF FAIL : WRITE=%h",
                     faulty_write_data);


        //----------------------------------------------------
        // END
        //----------------------------------------------------

        $display("");
        $display("========================================");
        $display("ALL 11 FAULT MODEL TESTS COMPLETE");
        $display("========================================");
        $display("");

        #20;

        $finish;

    end


    //--------------------------------------------------------
    // Waveform monitor
    //--------------------------------------------------------

    initial begin

       $monitor(
    "T=%0t | TYPE=%0d | ADDR=%0h | AGGR=%0h | NORMAL=%0h | FAULTY=%0h | WRITE=%0h | FW_WRITE=%0h",
    $time,
    fault_type,
    addr,
    aggressor_address,
    normal_read_data,
    faulty_read_data,
    write_data,
    faulty_write_data
);

    end

endmodule