`timescale 1ns/1ps

//============================================================
// Exhaustive fault-coverage run for the March mSR+ MBIST, with
// an independent behavioural cross-check.
//
// For every fault model, every parameter variant and every victim
// (and, for coupling faults, every ordered aggressor/victim pair
// with aggressor != victim) the complete RTL MBIST (mbist_top) is
// run once and classified as
//
//   DETECTED     the fault was ACTIVATED (it changed a read result,
//                a stored value or a victim cell) and the MBIST
//                reported fail
//   ESCAPED      activated, but the MBIST reported pass
//   NOT EXCITED  the March sequence never activated the fault
//                (pass is then the correct result)
//   FALSE ALARM  fail without any activation (always an error)
//
// Activation comes from fault_injection's fault_activated output,
// detection from the MBIST's final pass/fail, so the two are never
// confused. The run is repeated for three memory power-up states:
// unknown (X), all-0 and all-1.
//
// CROSS-CHECK: the same fault instance is also executed by a small
// behavioural March engine that is driven straight from the
// paper's Table VII sequences (not from the RTL). For March mSR+
// the engine and the RTL must agree on activation count and on
// detection for EVERY instance (otherwise: testbench error). The
// engine additionally runs March mSR, MATS++ and March C-, so the
// fault models can be sanity-checked against the paper's
// comparison table (e.g. all algorithms detect SAF/TF; mSR and
// mSR+ detect RDF/DRDF; MATS++/March C- do not detect CFdrd).
//
// Non-zero exit on: FALSE ALARM, timeout, pass/fail not one-hot,
// RTL/engine disagreement. ESCAPED / NOT EXCITED are results, not
// testbench errors.
//============================================================

module tb_fault_coverage #(
    parameter int ADDR_WIDTH = 3,
    parameter int DATA_WIDTH = 8,
    parameter bit VERBOSE    = 0      // 1: list every escaped / not-excited instance
);

    localparam int N      = 1 << ADDR_WIDTH;
    localparam int NMODEL = 14;
    localparam int NALGO  = 4;

    //--------------------------------------------------------
    // Independent March mSR+ reference (paper Table II/III),
    // NOT derived from the RTL. Op codes: 0=r0 1=r1 2=w0 3=w1
    //--------------------------------------------------------
    function automatic int ref_nops(input int s);
        case (s)
            0, 1, 3, 4, 10, 11 : ref_nops = 1;
            2, 5, 6, 8, 9      : ref_nops = 2;
            7, 12              : ref_nops = 3;
            default            : ref_nops = 0;
        endcase
    endfunction

    function automatic int ref_opcode(input int s, input int i);
        case (s)
            0:  ref_opcode = 2;                                   // w0
            1:  ref_opcode = 3;                                   // w1
            2:  ref_opcode = (i == 0) ? 1 : 2;                    // r1,w0
            3:  ref_opcode = 0;                                   // r0
            4:  ref_opcode = 0;                                   // r0
            5:  ref_opcode = (i == 0) ? 0 : 3;                    // r0,w1
            6:  ref_opcode = (i == 0) ? 1 : 3;                    // r1,w1
            7:  ref_opcode = (i == 0) ? 1 : ((i == 1) ? 2 : 3);   // r1,w0,w1
            8:  ref_opcode = (i == 0) ? 1 : 2;                    // r1,w0
            9:  ref_opcode = (i == 0) ? 0 : 3;                    // r0,w1
            10: ref_opcode = 1;                                   // r1
            11: ref_opcode = 1;                                   // r1
            12: ref_opcode = (i == 0) ? 1 : ((i == 1) ? 2 : 0);   // r1,w0,r0
            default: ref_opcode = -1;
        endcase
    endfunction

    // S0..S7 ascending, S8..S12 descending
    function automatic bit ref_up(input int s);
        ref_up = (s <= 7);
    endfunction

    function automatic bit ref_is_read(input int code);
        ref_is_read = (code == 0) || (code == 1);
    endfunction

    // data value of the operation: 0 for r0/w0, 1 for r1/w1
    function automatic bit ref_value(input int code);
        ref_value = (code == 1) || (code == 3);
    endfunction

    logic clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // Shared fault configuration
    // ---------------------------------------------------------
    logic rst, start;
    logic fault_enable;
    logic [3:0] fault_type;
    logic [ADDR_WIDTH-1:0] fault_address, aggressor_address;
    logic stuck_at_value, fault_variant;

    // ---------------------------------------------------------
    // RTL DUT
    // ---------------------------------------------------------
    logic busy, done, pass, fail;
    logic [ADDR_WIDTH-1:0] current_address;
    logic [3:0] march_step;
    logic [1:0] operation_index;
    logic direction_up;

    mbist_top #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .rst(rst), .start(start),
        .fault_enable(fault_enable), .fault_type(fault_type),
        .fault_address(fault_address), .aggressor_address(aggressor_address),
        .stuck_at_value(stuck_at_value), .fault_variant(fault_variant),
        .busy(busy), .done(done), .pass(pass), .fail(fail),
        .current_address(current_address), .march_step(march_step),
        .operation_index(operation_index), .direction_up(direction_up)
    );

    // ---------------------------------------------------------
    // Behavioural March engine (memory + fault injector only)
    // ---------------------------------------------------------
    logic e_rd, e_wr;
    logic [ADDR_WIDTH-1:0] e_addr;
    logic [DATA_WIDTH-1:0] e_wdata;
    logic [DATA_WIDTH-1:0] e_nread, e_victim, e_aggr, e_frd, e_fwd, e_fwdata;
    logic [ADDR_WIDTH-1:0] e_fwaddr;
    logic e_fwen, e_act;

    sram_model #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) eng_mem (
        .clk(clk), .write_en(e_wr), .write_addr(e_addr), .write_data(e_fwd),
        .read_addr(e_addr), .read_data(e_nread),
        .fault_write_en(e_fwen), .fault_write_addr(e_fwaddr), .fault_write_data(e_fwdata),
        .victim_read_addr(fault_address), .victim_read_data(e_victim),
        .aggr_read_addr(aggressor_address), .aggr_read_data(e_aggr)
    );

    fault_injection #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) eng_fi (
        .clk(clk), .rst(rst),
        .mem_read(e_rd), .mem_write(e_wr), .addr(e_addr),
        .normal_read_data(e_nread), .write_data(e_wdata),
        .victim_data(e_victim), .aggressor_data(e_aggr),
        .fault_enable(fault_enable), .fault_type(fault_type),
        .fault_address(fault_address), .aggressor_address(aggressor_address),
        .stuck_at_value(stuck_at_value), .fault_variant(fault_variant),
        .faulty_read_data(e_frd), .faulty_write_data(e_fwd),
        .fault_write_en(e_fwen), .fault_write_addr(e_fwaddr),
        .fault_write_data(e_fwdata), .fault_activated(e_act)
    );

    // March algorithm tables (op codes: 0=r0 1=r1 2=w0 3=w1)
    int  a_nelem;
    bit  a_up   [0:15];
    int  a_nops [0:15];
    int  a_op   [0:15][0:7];
    string a_name [0:NALGO-1];

    task automatic add_elem(input bit up, input int n, input int o0, input int o1,
                            input int o2, input int o3);
        begin
            a_up[a_nelem] = up; a_nops[a_nelem] = n;
            a_op[a_nelem][0] = o0; a_op[a_nelem][1] = o1;
            a_op[a_nelem][2] = o2; a_op[a_nelem][3] = o3;
            a_nelem++;
        end
    endtask

    task automatic load_algo(input int id);
        int s, i;
        begin
            a_nelem = 0;
            case (id)
                0: begin // March mSR+ (paper Table II/III), literal table
                    //        up n  op0 op1 op2 op3   (0=r0 1=r1 2=w0 3=w1)
                    add_elem(1, 1, 2, 0, 0, 0);   // S0  U(w0)
                    add_elem(1, 1, 3, 0, 0, 0);   // S1  U(w1)
                    add_elem(1, 2, 1, 2, 0, 0);   // S2  U(r1,w0)
                    add_elem(1, 1, 0, 0, 0, 0);   // S3  U(r0)
                    add_elem(1, 1, 0, 0, 0, 0);   // S4  U(r0)
                    add_elem(1, 2, 0, 3, 0, 0);   // S5  U(r0,w1)
                    add_elem(1, 2, 1, 3, 0, 0);   // S6  U(r1,w1)
                    add_elem(1, 3, 1, 2, 3, 0);   // S7  U(r1,w0,w1)
                    add_elem(0, 2, 1, 2, 0, 0);   // S8  D(r1,w0)
                    add_elem(0, 2, 0, 3, 0, 0);   // S9  D(r0,w1)
                    add_elem(0, 1, 1, 0, 0, 0);   // S10 D(r1)
                    add_elem(0, 1, 1, 0, 0, 0);   // S11 D(r1)
                    add_elem(0, 3, 1, 2, 0, 0);   // S12 D(r1,w0,r0)
                end
                1: begin // March mSR (paper Table VII): {w0; U(w1,r1,w0); U(r0,r0); U(w1); D(r1,w0,r0,w1); D(r1,r1)}
                    add_elem(1, 1, 2, 0, 0, 0);
                    add_elem(1, 3, 3, 1, 2, 0);
                    add_elem(1, 2, 0, 0, 0, 0);
                    add_elem(1, 1, 3, 0, 0, 0);
                    add_elem(0, 4, 1, 2, 0, 3);
                    add_elem(0, 2, 1, 1, 0, 0);
                end
                2: begin // MATS++: {w0; U(r0,w1); D(r1,w0,r0)}
                    add_elem(1, 1, 2, 0, 0, 0);
                    add_elem(1, 2, 0, 3, 0, 0);
                    add_elem(0, 3, 1, 2, 0, 0);
                end
                3: begin // March C-: {w0; U(r0,w1); U(r1,w0); D(r0,w1); D(r1,w0); r0}
                    add_elem(1, 1, 2, 0, 0, 0);
                    add_elem(1, 2, 0, 3, 0, 0);
                    add_elem(1, 2, 1, 2, 0, 0);
                    add_elem(0, 2, 0, 3, 0, 0);
                    add_elem(0, 2, 1, 2, 0, 0);
                    add_elem(1, 1, 0, 0, 0, 0);
                end
            endcase
        end
    endtask

    task automatic init_engine_memory(input int mode);
        int k;
        begin
            for (k = 0; k < N; k++) begin
                if (mode == 0)      eng_mem.mem[k] = 'x;
                else if (mode == 1) eng_mem.mem[k] = '0;
                else                eng_mem.mem[k] = '1;
            end
        end
    endtask

    // Run the loaded algorithm on the engine. detected = any read mismatch
    // (X counts as mismatch, like the RTL comparator); acts = activations.
    task automatic run_engine(input int mode, output bit detected, output int acts);
        int e, idx, k, a, code;
        bit val;
        begin
            init_engine_memory(mode);
            detected = 0; acts = 0;
            e_rd = 0; e_wr = 0; e_addr = '0; e_wdata = '0;
            for (e = 0; e < a_nelem; e++)
                for (idx = 0; idx < N; idx++) begin
                    a = a_up[e] ? idx : (N - 1 - idx);
                    for (k = 0; k < a_nops[e]; k++) begin
                        code = a_op[e][k];
                        val  = ref_value(code);
                        @(negedge clk);
                        e_addr = a;
                        if (ref_is_read(code)) begin
                            e_rd = 1; e_wr = 0; e_wdata = '0;
                        end
                        else begin
                            e_rd = 0; e_wr = 1; e_wdata = {DATA_WIDTH{val}};
                        end
                        #1;
                        if (e_act === 1'b1) acts++;
                        if (ref_is_read(code) && (e_frd !== {DATA_WIDTH{val}})) detected = 1;
                    end
                end
            @(negedge clk);
            e_rd = 0; e_wr = 0;
        end
    endtask

    // ---------------------------------------------------------
    // RTL run observation
    // ---------------------------------------------------------
    int act_cnt, mm_cnt;
    bit mon_on;

    always @(posedge clk) begin
        if (mon_on) begin
            if (dut.fault_activated === 1'b1) act_cnt++;
            if (dut.mismatch === 1'b1) mm_cnt++;
        end
    end

    // ---------------------------------------------------------
    // statistics  [model][variant]  (RTL March mSR+)
    // and per-algorithm detection totals (engine)
    // ---------------------------------------------------------
    int total [0:NMODEL-1][0:3];
    int det   [0:NMODEL-1][0:3];
    int esc   [0:NMODEL-1][0:3];
    int nex   [0:NMODEL-1][0:3];

    int a_total [0:NALGO-1][0:NMODEL-1];
    int a_det   [0:NALGO-1][0:NMODEL-1];

    int tb_errors = 0;
    int init_mode;

    string mname [0:NMODEL-1];

    task automatic run_instance(input int ft, input int fv, input int fvar,
                                input int v, input int a);
        int timeout, vi, al;
        bit eng_det;
        int eng_act;
        bit rtl_det;
        begin
            // ---------------- RTL ----------------
            for (int k = 0; k < N; k++) begin
                if (init_mode == 0)      dut.sram_model_inst.mem[k] = 'x;
                else if (init_mode == 1) dut.sram_model_inst.mem[k] = '0;
                else                     dut.sram_model_inst.mem[k] = '1;
            end

            rst = 1; start = 0;
            fault_enable = 1; fault_type = ft;
            stuck_at_value = fv; fault_variant = fvar;
            fault_address = v; aggressor_address = a;
            @(negedge clk); @(negedge clk);
            rst = 0;
            @(negedge clk);

            act_cnt = 0; mm_cnt = 0;
            mon_on = 1;

            start = 1;
            @(negedge clk);
            start = 0;

            timeout = 22 * N + 100;
            while (!done && timeout > 0) begin
                @(negedge clk);
                timeout--;
            end

            if (!done) begin
                $display("TB ERROR: timeout (%s fv %0d fvar %0d V%0d A%0d)", mname[ft], fv, fvar, v, a);
                tb_errors++;
            end
            else if ((pass ^ fail) !== 1'b1) begin
                $display("TB ERROR: done without one-hot pass/fail (%s V%0d A%0d) pass=%b fail=%b",
                         mname[ft], v, a, pass, fail);
                tb_errors++;
            end
            mon_on = 0;

            rtl_det = (fail === 1'b1);
            vi = fvar * 2 + fv;
            total[ft][vi]++;

            if (act_cnt > 0 && fail === 1'b1)        det[ft][vi]++;
            else if (act_cnt > 0 && pass === 1'b1) begin
                esc[ft][vi]++;
                if (VERBOSE)
                    $display("  ESCAPED     %-7s fv=%0d fvar=%0d V=%0d A=%0d (init %0d) activations=%0d",
                             mname[ft], fv, fvar, v, a, init_mode, act_cnt);
            end
            else if (act_cnt == 0 && pass === 1'b1) begin
                nex[ft][vi]++;
                if (VERBOSE)
                    $display("  NOT EXCITED %-7s fv=%0d fvar=%0d V=%0d A=%0d (init %0d)",
                             mname[ft], fv, fvar, v, a, init_mode);
            end
            else begin
                $display("TB ERROR: FALSE ALARM %s fv=%0d fvar=%0d V=%0d A=%0d: fail with no activation (mismatches=%0d)",
                         mname[ft], fv, fvar, v, a, mm_cnt);
                tb_errors++;
            end

            if (fail === 1'b1 && mm_cnt == 0) begin
                $display("TB ERROR: fail without any comparator mismatch");
                tb_errors++;
            end

            // ---------------- behavioural engine, all algorithms ----------------
            for (al = 0; al < NALGO; al++) begin
                load_algo(al);
                if (al == 0) begin : chk_tbl
                    int nops_sum;
                    nops_sum = 0;
                    for (int e = 0; e < a_nelem; e++) nops_sum += a_nops[e];
                    if (a_nelem != 13 || nops_sum != 22) begin
                        $display("TB ERROR: mSR+ engine table wrong (elements=%0d ops/cell=%0d, expected 13/22)", a_nelem, nops_sum);
                        tb_errors++;
                    end
                end
                run_engine(init_mode, eng_det, eng_act);
                a_total[al][ft]++;
                if (eng_det && eng_act > 0) a_det[al][ft]++;

                if (al == 0) begin
                    if ((eng_det !== rtl_det) || (eng_act !== act_cnt)) begin
                        $display("TB ERROR: RTL and behavioural March mSR+ disagree: %s fv=%0d fvar=%0d V=%0d A=%0d  RTL(det=%0b act=%0d) engine(det=%0b act=%0d)",
                                 mname[ft], fv, fvar, v, a, rtl_det, act_cnt, eng_det, eng_act);
                        tb_errors++;
                    end
                end
                else if (eng_det && eng_act == 0) begin
                    $display("TB ERROR: engine false alarm (%s, algo %0d) V=%0d A=%0d", mname[ft], al, v, a);
                    tb_errors++;
                end
            end
        end
    endtask

    int ft, fv, fvar, v, a, vi, fv_max, fvar_max, al, m;
    int g_total, g_det, g_esc, g_nex;
    bit coupling;
    int mt, mdet, mesc, mnex;
    int pi, p_tot = 0, p_det = 0, p_full = 0;
    int pmap [0:10];
    string pname [0:10];

    initial begin
        mname[0]  = "SAF";    mname[1]  = "TF";     mname[2]  = "CFID";   mname[3]  = "CFDRD";
        mname[4]  = "CFIN";   mname[5]  = "RDF";    mname[6]  = "DRDF";   mname[7]  = "IRF";
        mname[8]  = "CFTR";   mname[9]  = "CFWD";   mname[10] = "WDF";
        mname[11] = "CFDRD_P"; mname[12] = "CFWD_P"; mname[13] = "WDF_P";
        pmap[0] = 0;  pname[0] = "SAF";    pmap[1] = 1;   pname[1] = "TF";
        pmap[2] = 4;  pname[2] = "CFid";   pmap[3] = 11;  pname[3] = "CFdrd";
        pmap[4] = 2;  pname[4] = "CFin";   pmap[5] = 5;   pname[5] = "RDF";
        pmap[6] = 6;  pname[6] = "DRDF";   pmap[7] = 7;   pname[7] = "IRF";
        pmap[8] = 8;  pname[8] = "CFtr";   pmap[9] = 12;  pname[9] = "CFwd";
        pmap[10] = 13; pname[10] = "WDF";
        a_name[0] = "mSR+"; a_name[1] = "mSR"; a_name[2] = "MATS++"; a_name[3] = "March C-";

        rst = 1; start = 0; fault_enable = 0; fault_type = 0;
        fault_address = 0; aggressor_address = 0; stuck_at_value = 0; fault_variant = 0;
        mon_on = 0; e_rd = 0; e_wr = 0; e_addr = '0; e_wdata = '0;

        for (init_mode = 0; init_mode < 3; init_mode++) begin

            for (ft = 0; ft < NMODEL; ft++) begin
                for (vi = 0; vi < 4; vi++) begin
                    total[ft][vi] = 0; det[ft][vi] = 0; esc[ft][vi] = 0; nex[ft][vi] = 0;
                end
                for (al = 0; al < NALGO; al++) begin a_total[al][ft] = 0; a_det[al][ft] = 0; end
            end

            $display("");
            $display("=====================================================================");
            $display(" March mSR+ fault coverage  (ADDR_WIDTH=%0d -> %0d cells, DATA_WIDTH=%0d)",
                     ADDR_WIDTH, N, DATA_WIDTH);
            $display(" memory power-up state: %s",
                     init_mode == 0 ? "unknown (X)" : (init_mode == 1 ? "all zeros" : "all ones"));
            $display("=====================================================================");

            for (ft = 0; ft < NMODEL; ft++) begin
                coupling = (ft == 2) || (ft == 3) || (ft == 4) || (ft == 8) || (ft == 9) ||
                           (ft == 11) || (ft == 12) || (ft == 13);
                // CFIN and CFWD_P ignore fv; WDF_P and single-cell models ignore fvar
                fv_max   = (ft == 4 || ft == 12) ? 0 : 1;
                fvar_max = (coupling && ft != 13) ? 1 : 0;   // WDF_P ignores fvar

                for (fvar = 0; fvar <= fvar_max; fvar++)
                    for (fv = 0; fv <= fv_max; fv++)
                        for (v = 0; v < N; v++) begin
                            if (!coupling)
                                run_instance(ft, fv, fvar, v, (v + 1) % N);
                            else
                                for (a = 0; a < N; a++)
                                    if (a != v)
                                        run_instance(ft, fv, fvar, v, a);
                        end
            end

            // ---- RTL summary ----
            $display("");
            $display(" RTL March mSR+ (mbist_top)");
            $display(" model    variant(fv,fvar)  instances  detected  escaped  not-excited");
            $display(" -------  ----------------  ---------  --------  -------  -----------");
            g_total = 0; g_det = 0; g_esc = 0; g_nex = 0;
            for (ft = 0; ft < NMODEL; ft++) begin
                mt = 0; mdet = 0; mesc = 0; mnex = 0;
                for (vi = 0; vi < 4; vi++)
                    if (total[ft][vi] > 0) begin
                        $display(" %-7s  fv=%0d fvar=%0d        %5d     %5d    %5d      %5d",
                                 mname[ft], vi % 2, vi / 2, total[ft][vi], det[ft][vi],
                                 esc[ft][vi], nex[ft][vi]);
                        mt += total[ft][vi]; mdet += det[ft][vi];
                        mesc += esc[ft][vi]; mnex += nex[ft][vi];
                    end
                $display(" %-7s  ALL VARIANTS      %5d     %5d    %5d      %5d   => %0d%% detected",
                         mname[ft], mt, mdet, mesc, mnex, (mt == 0) ? 0 : (100 * mdet / mt));
                $display("");
                g_total += mt; g_det += mdet; g_esc += mesc; g_nex += mnex;
            end
            $display(" TOTAL: %0d instances, %0d detected, %0d escaped, %0d not excited",
                     g_total, g_det, g_esc, g_nex);

            // ---- algorithm comparison (behavioural engine) ----
            $display("");
            $display(" Detected / instances by algorithm (behavioural engine; mSR+ column == RTL)");
            $display(" model     %8s %8s %8s %8s", a_name[0], a_name[1], a_name[2], a_name[3]);
            for (ft = 0; ft < NMODEL; ft++)
                $display(" %-7s   %3d/%-4d %3d/%-4d %3d/%-4d %3d/%-4d", mname[ft],
                         a_det[0][ft], a_total[0][ft], a_det[1][ft], a_total[1][ft],
                         a_det[2][ft], a_total[2][ft], a_det[3][ft], a_total[3][ft]);

            // ---- paper-style summary: the paper's 11 fault models, in the paper's
            //      order, each mapped to the model that follows the paper's Table I
            //      one-line definition (see docs/FAULT_MODEL_MAPPING.md) ----
            $display("");
            $display(" Paper-style summary: the 11 fault models of the reference paper");
            $display(" (Table I definitions; mapping: CFid->CFIN  CFin->CFID  CFdrd->CFDRD_P  CFwd->CFWD_P  WDF->WDF_P)");
            $display(" paper model  our model    mSR+(RTL)        mSR  MATS++  March C-");
            for (pi = 0; pi < 11; pi++) begin
                ft = pmap[pi];
                $display(" %-10s  %-8s   %3d/%-4d %4s   %3d/%-4d %3d/%-4d %3d/%-4d",
                         pname[pi], mname[ft], a_det[0][ft], a_total[0][ft],
                         (a_det[0][ft] == a_total[0][ft]) ? "100%" : " <100",
                         a_det[1][ft], a_total[1][ft], a_det[2][ft], a_total[2][ft],
                         a_det[3][ft], a_total[3][ft]);
                p_tot += a_total[0][ft]; p_det += a_det[0][ft];
                if (a_det[0][ft] == a_total[0][ft]) p_full++;
            end
            $display(" => mSR+ detects 100%% of the injected instances for %0d of the paper's 11 fault models", p_full);
            p_tot = 0; p_det = 0; p_full = 0;
        end

        $display("");
        $display("----------------------------------------");
        if (tb_errors == 0) $display("FAULT COVERAGE RUN COMPLETED (no testbench errors, RTL == behavioural March mSR+ on every instance)");
        else                $display("FAULT COVERAGE RUN FAILED: %0d testbench errors", tb_errors);
        $display("----------------------------------------");
        if (tb_errors != 0) $fatal(1, "fault coverage testbench errors");
        $finish;
    end

endmodule
