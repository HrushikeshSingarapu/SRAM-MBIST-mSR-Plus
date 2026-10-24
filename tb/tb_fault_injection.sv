`timescale 1ns/1ps

//============================================================
// Fault injection unit test (directed, combinational)
//
// Drives fault_injection directly (no March test) and checks
// the exact behaviour of every model for the trigger cases and
// the NON-trigger cases (so a model that fires too often fails
// too). V = victim (addr 2), A = aggressor (addr 5), O = other.
// Z = all-zero word, W = all-one word.
//============================================================

module tb_fault_injection;

    localparam int AW = 3;
    localparam int DW = 8;

    localparam logic [DW-1:0] Z = 8'h00;
    localparam logic [DW-1:0] W = 8'hFF;

    localparam logic [3:0] SAF = 0, TF = 1, CFID = 2, CFDRD = 3, CFIN = 4, RDF = 5,
                           DRDF = 6, IRF = 7, CFTR = 8, CFWD = 9, WDF = 10,
                           CFDRD_P = 11, CFWD_P = 12, WDF_P = 13;

    localparam logic [AW-1:0] V = 3'd2;
    localparam logic [AW-1:0] A = 3'd5;
    localparam logic [AW-1:0] O = 3'd7;

    logic clk = 0, rst = 0;

    logic              mem_read, mem_write;
    logic [AW-1:0]     addr;
    logic [DW-1:0]     normal_read_data, write_data, victim_data, aggressor_data;
    logic              fault_enable;
    logic [3:0]        fault_type;
    logic [AW-1:0]     fault_address, aggressor_address;
    logic              stuck_at_value, fault_variant;
    logic [DW-1:0]     faulty_read_data, faulty_write_data, fault_write_data;
    logic              fault_write_en, fault_activated;
    logic [AW-1:0]     fault_write_addr;

    fault_injection #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW)) dut (
        .clk(clk), .rst(rst),
        .mem_read(mem_read), .mem_write(mem_write), .addr(addr),
        .normal_read_data(normal_read_data), .write_data(write_data),
        .victim_data(victim_data), .aggressor_data(aggressor_data),
        .fault_enable(fault_enable), .fault_type(fault_type),
        .fault_address(fault_address), .aggressor_address(aggressor_address),
        .stuck_at_value(stuck_at_value), .fault_variant(fault_variant),
        .faulty_read_data(faulty_read_data), .faulty_write_data(faulty_write_data),
        .fault_write_en(fault_write_en), .fault_write_addr(fault_write_addr),
        .fault_write_data(fault_write_data), .fault_activated(fault_activated)
    );

    int errors = 0;
    int cases  = 0;
    int k;
    logic [3:0] cf [0:7];

    // Operation helper.
    //   kind: 0 = read, 1 = write
    //   cur : current content of the accessed cell (read data / old value)
    //   wd  : write data (writes only)
    //   vd/ad : current content of victim / aggressor
    //   expectations: exp_rd (read result), exp_wd (stored write value),
    //                 exp_fwen, exp_fwd (victim write data), exp_act
    task automatic t(input string name,
                     input logic [3:0] ft, input logic fv, input logic fvar,
                     input logic [AW-1:0] a, input bit kind,
                     input logic [DW-1:0] cur, input logic [DW-1:0] wd,
                     input logic [DW-1:0] vd, input logic [DW-1:0] ad,
                     input logic [DW-1:0] exp_rd, input logic [DW-1:0] exp_wd,
                     input logic exp_fwen, input logic [DW-1:0] exp_fwd,
                     input logic exp_act);
        begin
            fault_enable = 1; fault_type = ft;
            stuck_at_value = fv; fault_variant = fvar;
            fault_address = V; aggressor_address = A;
            addr = a; mem_read = !kind; mem_write = kind;
            normal_read_data = cur; write_data = kind ? wd : Z;
            victim_data = vd; aggressor_data = ad;
            #1;
            cases++;
            if (!kind && faulty_read_data !== exp_rd) begin
                $display("ERROR %s: read data %h expected %h", name, faulty_read_data, exp_rd); errors++;
            end
            if (kind && faulty_write_data !== exp_wd) begin
                $display("ERROR %s: stored write data %h expected %h", name, faulty_write_data, exp_wd); errors++;
            end
            if (fault_write_en !== exp_fwen) begin
                $display("ERROR %s: fault_write_en=%b expected %b", name, fault_write_en, exp_fwen); errors++;
            end
            if (exp_fwen && fault_write_data !== exp_fwd) begin
                $display("ERROR %s: victim write data %h expected %h", name, fault_write_data, exp_fwd); errors++;
            end
            if (exp_fwen && fault_write_addr !== V) begin
                $display("ERROR %s: victim write address %0d expected %0d", name, fault_write_addr, V); errors++;
            end
            if (fault_activated !== exp_act) begin
                $display("ERROR %s: fault_activated=%b expected %b", name, fault_activated, exp_act); errors++;
            end
        end
    endtask

    // shorthand: expectations for "no effect" on a read / write
    task automatic no_rd(input string n, input logic [3:0] ft, input logic fv, input logic fvar,
                         input logic [AW-1:0] a, input logic [DW-1:0] cur,
                         input logic [DW-1:0] vd, input logic [DW-1:0] ad);
        t(n, ft, fv, fvar, a, 1'b0, cur, Z, vd, ad, cur, Z, 1'b0, Z, 1'b0);
    endtask
    task automatic no_wr(input string n, input logic [3:0] ft, input logic fv, input logic fvar,
                         input logic [AW-1:0] a, input logic [DW-1:0] cur, input logic [DW-1:0] wd,
                         input logic [DW-1:0] vd, input logic [DW-1:0] ad);
        t(n, ft, fv, fvar, a, 1'b1, cur, wd, vd, ad, Z, wd, 1'b0, Z, 1'b0);
    endtask

    initial begin

        // ---------- fault disabled: transparent for every type ----------
        begin
            for (k = 0; k < 14; k++) begin
                fault_enable = 0; fault_type = k;
                stuck_at_value = 1; fault_variant = 1;
                fault_address = V; aggressor_address = A;
                addr = V; mem_read = 1; mem_write = 0;
                normal_read_data = Z; write_data = W; victim_data = Z; aggressor_data = Z;
                #1; cases++;
                if (faulty_read_data !== Z || faulty_write_data !== W ||
                    fault_write_en !== 1'b0 || fault_activated !== 1'b0) begin
                    $display("ERROR disabled fault type %0d is not transparent", k); errors++;
                end
            end
        end

        // ---------- SAF ----------
        t("SAF0 write 1 -> stays 0", SAF, 0, 0, V, 1'b1, Z, W, Z, Z, Z, Z, 0, Z, 1);
        t("SAF0 write 0 (no effect)", SAF, 0, 0, V, 1'b1, Z, Z, Z, Z, Z, Z, 0, Z, 0);
        t("SAF0 read returns 0",      SAF, 0, 0, V, 1'b0, W, Z, W, Z, Z, Z, 0, Z, 1);
        t("SAF1 write 0 -> stays 1", SAF, 1, 0, V, 1'b1, W, Z, W, Z, W, W, 0, Z, 1);
        t("SAF1 read returns 1",      SAF, 1, 0, V, 1'b0, Z, Z, Z, Z, W, W, 0, Z, 1);
        no_wr("SAF other-address write", SAF, 0, 0, O, Z, W, Z, Z);
        no_rd("SAF other-address read",  SAF, 1, 0, O, Z, Z, Z);

        // ---------- TF ----------
        t("TF0 up-transition blocked", TF, 0, 0, V, 1'b1, Z, W, Z, Z, Z, Z, 0, Z, 1);
        no_wr("TF0 down-transition ok", TF, 0, 0, V, W, Z, W, Z);
        no_wr("TF0 non-transition 0w0 ok", TF, 0, 0, V, Z, Z, Z, Z);
        no_wr("TF0 non-transition 1w1 ok", TF, 0, 0, V, W, W, W, Z);
        t("TF1 down-transition blocked", TF, 1, 0, V, 1'b1, W, Z, W, Z, Z, W, 0, Z, 1);
        no_wr("TF1 up-transition ok", TF, 1, 0, V, Z, W, Z, Z);
        no_wr("TF other-address write", TF, 0, 0, O, Z, W, Z, Z);
        no_rd("TF read unaffected", TF, 0, 0, V, Z, Z, Z);

        // ---------- WDF (non-transition write flips) ----------
        t("WDF0 0w0 flips to 1", WDF, 0, 0, V, 1'b1, Z, Z, Z, Z, Z, W, 0, Z, 1);
        no_wr("WDF0 1w1 ok", WDF, 0, 0, V, W, W, W, Z);
        no_wr("WDF0 transition 0w1 ok", WDF, 0, 0, V, Z, W, Z, Z);
        no_wr("WDF0 transition 1w0 ok", WDF, 0, 0, V, W, Z, W, Z);
        t("WDF1 1w1 flips to 0", WDF, 1, 0, V, 1'b1, W, W, W, Z, Z, Z, 0, Z, 1);
        no_wr("WDF1 0w0 ok", WDF, 1, 0, V, Z, Z, Z, Z);
        no_wr("WDF other-address write", WDF, 0, 0, O, Z, Z, Z, Z);
        no_rd("WDF read unaffected", WDF, 0, 0, V, Z, Z, Z);

        // ---------- RDF (read flips cell, returns flipped value) ----------
        t("RDF0 read of 0 -> returns 1, cell flips to 1", RDF, 0, 0, V, 1'b0, Z, Z, Z, Z, W, Z, 1, W, 1);
        no_rd("RDF0 read of 1 ok", RDF, 0, 0, V, W, W, Z);
        t("RDF1 read of 1 -> returns 0, cell flips to 0", RDF, 1, 0, V, 1'b0, W, Z, W, Z, Z, Z, 1, Z, 1);
        no_rd("RDF1 read of 0 ok", RDF, 1, 0, V, Z, Z, Z);
        no_rd("RDF other-address read", RDF, 0, 0, O, Z, Z, Z);
        no_wr("RDF write unaffected", RDF, 0, 0, V, Z, W, Z, Z);

        // ---------- DRDF (read correct, cell flips) ----------
        t("DRDF0 read of 0 -> returns 0, cell flips to 1", DRDF, 0, 0, V, 1'b0, Z, Z, Z, Z, Z, Z, 1, W, 1);
        no_rd("DRDF0 read of 1 ok", DRDF, 0, 0, V, W, W, Z);
        t("DRDF1 read of 1 -> returns 1, cell flips to 0", DRDF, 1, 0, V, 1'b0, W, Z, W, Z, W, Z, 1, Z, 1);
        no_rd("DRDF other-address read", DRDF, 1, 0, O, W, W, Z);
        no_wr("DRDF write unaffected", DRDF, 0, 0, V, Z, W, Z, Z);

        // ---------- IRF (read returns wrong value, cell intact) ----------
        t("IRF0 read of 0 returns 1, cell intact", IRF, 0, 0, V, 1'b0, Z, Z, Z, Z, W, Z, 0, Z, 1);
        no_rd("IRF0 read of 1 ok", IRF, 0, 0, V, W, W, Z);
        t("IRF1 read of 1 returns 0, cell intact", IRF, 1, 0, V, 1'b0, W, Z, W, Z, Z, Z, 0, Z, 1);
        no_rd("IRF other-address read", IRF, 0, 0, O, Z, Z, Z);
        no_wr("IRF write unaffected", IRF, 0, 0, V, Z, W, Z, Z);

        // ---------- CFIN (aggressor transition inverts victim) ----------
        t("CFIN up: A 0w1 inverts V (0->1)", CFIN, 0, 0, A, 1'b1, Z, W, Z, Z, Z, W, 1, W, 1);
        t("CFIN up: A 0w1 inverts V (1->0)", CFIN, 0, 0, A, 1'b1, Z, W, W, Z, Z, W, 1, Z, 1);
        no_wr("CFIN up: A 1w0 no trigger", CFIN, 0, 0, A, W, Z, Z, W);
        no_wr("CFIN up: A 0w0 no trigger", CFIN, 0, 0, A, Z, Z, Z, Z);
        no_wr("CFIN up: A 1w1 no trigger", CFIN, 0, 0, A, W, W, Z, W);
        t("CFIN down: A 1w0 inverts V", CFIN, 0, 1, A, 1'b1, W, Z, Z, W, Z, Z, 1, W, 1);
        no_wr("CFIN down: A 0w1 no trigger", CFIN, 0, 1, A, Z, W, Z, Z);
        no_rd("CFIN: read of A no trigger", CFIN, 0, 0, A, Z, Z, Z);
        no_wr("CFIN: write to V no trigger", CFIN, 0, 0, V, Z, W, Z, Z);
        no_wr("CFIN: write to other no trigger", CFIN, 0, 0, O, Z, W, Z, Z);

        // ---------- CFID (aggressor transition forces victim = fv) ----------
        t("CFID up/fv0: A 0w1 forces V=0", CFID, 0, 0, A, 1'b1, Z, W, W, Z, Z, W, 1, Z, 1);
        t("CFID up/fv1: A 0w1 forces V=1", CFID, 1, 0, A, 1'b1, Z, W, Z, Z, Z, W, 1, W, 1);
        t("CFID down/fv1: A 1w0 forces V=1", CFID, 1, 1, A, 1'b1, W, Z, Z, W, Z, Z, 1, W, 1);
        t("CFID up: V already = fv (write is a no-op, not activated)", CFID, 0, 0, A, 1'b1, Z, W, Z, Z, Z, W, 1, Z, 0);
        no_wr("CFID up: A 1w0 no trigger", CFID, 0, 0, A, W, Z, W, W);
        no_rd("CFID: read of A no trigger", CFID, 0, 0, A, Z, W, Z);

        // ---------- CFTR (A in state a blocks V fv->~fv) ----------
        t("CFTR fv0/a0: V 0w1 blocked while A=0", CFTR, 0, 0, V, 1'b1, Z, W, Z, Z, Z, Z, 0, Z, 1);
        no_wr("CFTR fv0/a0: A=1 -> V 0w1 ok", CFTR, 0, 0, V, Z, W, Z, W);
        t("CFTR fv0/a1: V 0w1 blocked while A=1", CFTR, 0, 1, V, 1'b1, Z, W, Z, W, Z, Z, 0, Z, 1);
        no_wr("CFTR fv0/a1: A=0 -> V 0w1 ok", CFTR, 0, 1, V, Z, W, Z, Z);
        t("CFTR fv1/a1: V 1w0 blocked while A=1", CFTR, 1, 1, V, 1'b1, W, Z, W, W, Z, W, 0, Z, 1);
        no_wr("CFTR fv0: V 1w0 (other direction) ok", CFTR, 0, 0, V, W, Z, W, Z);
        no_wr("CFTR: V non-transition ok", CFTR, 0, 0, V, Z, Z, Z, Z);
        no_wr("CFTR: write to A no effect", CFTR, 0, 0, A, Z, W, Z, Z);

        // ---------- CFWD (A in state a; non-transition write x to V flips it) ----------
        t("CFWD fv0/a0: V 0w0 flips while A=0", CFWD, 0, 0, V, 1'b1, Z, Z, Z, Z, Z, W, 0, Z, 1);
        no_wr("CFWD fv0/a0: A=1 -> V 0w0 ok", CFWD, 0, 0, V, Z, Z, Z, W);
        t("CFWD fv1/a1: V 1w1 flips while A=1", CFWD, 1, 1, V, 1'b1, W, W, W, W, Z, Z, 0, Z, 1);
        no_wr("CFWD fv0: V transition write ok", CFWD, 0, 0, V, Z, W, Z, Z);
        no_wr("CFWD fv0: V 1w1 (other value) ok", CFWD, 0, 0, V, W, W, W, Z);
        no_wr("CFWD: write to A no effect", CFWD, 0, 0, A, Z, Z, Z, Z);

        // ---------- CFDRD (A in state a; read V holding x -> correct, V flips) ----------
        t("CFDRD fv0/a0: read V(0) correct, V flips to 1", CFDRD, 0, 0, V, 1'b0, Z, Z, Z, Z, Z, Z, 1, W, 1);
        no_rd("CFDRD fv0/a0: A=1 no effect", CFDRD, 0, 0, V, Z, Z, W);
        t("CFDRD fv1/a1: read V(1) correct, V flips to 0", CFDRD, 1, 1, V, 1'b0, W, Z, W, W, W, Z, 1, Z, 1);
        no_rd("CFDRD fv0: V holds 1 no effect", CFDRD, 0, 0, V, W, W, Z);
        no_rd("CFDRD: read of A no effect", CFDRD, 0, 0, A, Z, Z, Z);
        no_wr("CFDRD: write to V no effect", CFDRD, 0, 0, V, Z, W, Z, Z);


        // ---------- CFDRD_P (paper-literal: aggressor read disturbs victim) ----------
        t("CFDRD_P fv0/a0: read A(0) flips V(0)->1", CFDRD_P, 0, 0, A, 1'b0, Z, Z, Z, Z, Z, Z, 1, W, 1);
        no_rd("CFDRD_P fv0/a0: A holds 1 -> no effect", CFDRD_P, 0, 0, A, W, Z, W);
        no_rd("CFDRD_P fv0/a0: V holds 1 -> no effect", CFDRD_P, 0, 0, A, Z, W, Z);
        t("CFDRD_P fv1/a1: read A(1) flips V(1)->0", CFDRD_P, 1, 1, A, 1'b0, W, Z, W, W, W, Z, 1, Z, 1);
        no_rd("CFDRD_P: read of V no effect", CFDRD_P, 0, 0, V, Z, Z, Z);
        no_wr("CFDRD_P: write to A no effect", CFDRD_P, 0, 0, A, Z, W, Z, Z);

        // ---------- CFWD_P (paper-literal: aggressor write copies into victim) ----------
        t("CFWD_P a0: write 0 to A also writes 0 to V", CFWD_P, 0, 0, A, 1'b1, W, Z, W, W, Z, Z, 1, Z, 1);
        t("CFWD_P a1: write 1 to A also writes 1 to V", CFWD_P, 0, 1, A, 1'b1, Z, W, Z, Z, Z, W, 1, W, 1);
        no_wr("CFWD_P a0: write 1 to A (other value) no effect", CFWD_P, 0, 0, A, Z, W, Z, Z);
        no_rd("CFWD_P: read of A no effect", CFWD_P, 0, 0, A, Z, Z, Z);
        no_wr("CFWD_P: write to V no effect", CFWD_P, 0, 0, V, Z, W, Z, Z);

        // ---------- WDF_P (paper-literal: word-line activation of A disturbs V) ----------
        t("WDF_P fv0: read of A flips V(0)->1", WDF_P, 0, 0, A, 1'b0, Z, Z, Z, Z, Z, Z, 1, W, 1);
        t("WDF_P fv0: write to A flips V(0)->1", WDF_P, 0, 0, A, 1'b1, Z, W, Z, Z, Z, W, 1, W, 1);
        t("WDF_P fv1: read of A flips V(1)->0", WDF_P, 1, 0, A, 1'b0, W, Z, W, W, W, Z, 1, Z, 1);
        t("WDF_P fv1: write to A flips V(1)->0", WDF_P, 1, 0, A, 1'b1, W, Z, W, W, Z, Z, 1, Z, 1);
        no_rd("WDF_P fv0: V holds 1 -> no effect", WDF_P, 0, 0, A, Z, W, Z);
        no_wr("WDF_P fv1: V holds 0 -> no effect", WDF_P, 1, 0, A, Z, W, Z, Z);
        no_rd("WDF_P: read of V no effect", WDF_P, 0, 0, V, Z, Z, Z);
        no_wr("WDF_P: write to other cell no effect", WDF_P, 0, 0, O, Z, W, Z, Z);

        // ---------- aggressor == victim is not a valid coupling pair ----------
        begin
            cf[0] = CFID; cf[1] = CFIN; cf[2] = CFTR; cf[3] = CFWD; cf[4] = CFDRD; cf[5] = CFDRD_P; cf[6] = CFWD_P; cf[7] = WDF_P;
            for (k = 0; k < 8; k++) begin
                fault_enable = 1; fault_type = cf[k]; stuck_at_value = 0; fault_variant = 0;
                fault_address = V; aggressor_address = V;
                addr = V; mem_write = 1; mem_read = 0;
                normal_read_data = Z; write_data = W; victim_data = Z; aggressor_data = Z;
                #1; cases++;
                if (fault_write_en !== 1'b0 || faulty_write_data !== W || fault_activated !== 1'b0) begin
                    $display("ERROR coupling fault %0d active with aggressor == victim", cf[k]); errors++;
                end
            end
        end

        $display("----------------------------------------");
        if (errors == 0) $display("FAULT INJECTION TEST PASSED (%0d directed cases)", cases);
        else             $display("FAULT INJECTION TEST FAILED: %0d errors in %0d cases", errors, cases);
        $display("----------------------------------------");
        if (errors != 0) $fatal(1, "fault injection errors");
        $finish;
    end

endmodule
